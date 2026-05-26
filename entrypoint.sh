#!/usr/bin/env bash
set -e


# Strip [tool.uv.sources] section and remove those packages from dependencies.
# Local filesystem paths won't exist in container, and private packages won't resolve.
# Args: $1 = path to pyproject.toml
strip_local_sources() {
  local file="$1"

  if ! grep -q '^\[tool\.uv\.sources\]' "$file"; then
    return 0
  fi

  printf -- '  - Stripping local/private sources from pyproject.toml ...\n'

  local local_packages
  local_packages=$(awk '
    /^\[tool\.uv\.sources\]/ { in_section=1; next }
    /^\[/ { in_section=0 }
    in_section && /^[a-zA-Z0-9_-]+[ ]*=/ {
      gsub(/[ ]*=.*/, "");
      print
    }
  ' "$file")

  local pattern
  pattern=$(echo "$local_packages" | tr '\n' '|' | sed 's/|$//')

  awk -v pkgs="$pattern" '
    BEGIN { in_deps=0 }
    /^\[tool\.uv\.sources\]/ { skip_section=1; next }
    /^\[/ && skip_section { skip_section=0 }
    skip_section { next }
    /^dependencies[ ]*=[ ]*\[/ { in_deps=1 }
    in_deps && /^\]/ { in_deps=0 }
    in_deps && pkgs != "" {
      for (i=split(pkgs,arr,"|"); i>0; i--) {
        regex = "\"" arr[i] "([\"\\[>=<~!]|$)"
        if ($0 ~ regex) next
      }
    }
    { print }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

  if [[ -n "$local_packages" ]]; then
    printf -- "    - Skipped packages: %s\n" "$(echo "$local_packages" | tr '\n' ' ')"
  fi
}


# Extract member directory names from [tool.uv.workspace] members = [...].
# Handles both single-line and multi-line array formats. Literal paths only (no globs).
# Args: $1 = path to pyproject.toml
parse_workspace_members() {
  local file="$1"
  awk '
    /^\[tool\.uv\.workspace\]/ { in_section=1; next }
    in_section && /^\[/ { in_section=0 }
    in_section { print }
  ' "$file" | grep -oE '"[^"]+"' | tr -d '"'
}


# --- Main ---

printf '\n🐳 docker-pip-audit\n\n'

# Argument parsing
ALL_MODE=false
DEPENDENCY_GROUPS=()
for arg in "$@"; do
  case "$arg" in
    --all) ALL_MODE=true ;;
    *)     DEPENDENCY_GROUPS+=("$arg") ;;
  esac
done

# Project detection
if [[ -r /workspace/pyproject.toml ]]; then
  REQUIREMENTS="pyproject.toml"
elif [[ -r /workspace/requirements.txt ]]; then
  REQUIREMENTS="requirements.txt"
  if $ALL_MODE; then
    printf '‼️  The all command requires a pyproject.toml (requirements.txt projects have no groups or workspace).\n\n'
    exit 1
  fi
else
  printf '‼️  This utility requires a [pyproject.toml] or [requirements.txt] file in the working directory.\n\n'
  exit 1
fi

printf '🛠️  Preparing shadow project [%s] ...\n' "$REQUIREMENTS"
mkdir /project
cd /project

if [[ $REQUIREMENTS == "pyproject.toml" ]]; then
  if $ALL_MODE; then

    # ── Mode 3: all groups + workspace via uv export ──────────────────────────

    if [[ ! -r /workspace/uv.lock ]]; then
      printf '\n‼️  The all command requires a uv.lock file. Run "uv lock" in your project first.\n\n'
      exit 1
    fi

    cp /workspace/pyproject.toml .
    cp /workspace/uv.lock .

    if grep -q '^\[tool\.uv\.workspace\]' pyproject.toml; then
      printf '  - uv workspace detected, copying member pyproject.toml files ...\n'
      while IFS= read -r member; do
        [[ "$member" == "." ]] && continue
        for src in /workspace/$member; do
          [[ -f "$src/pyproject.toml" ]] || continue
          local_rel="${src#/workspace/}"
          mkdir -p "$local_rel"
          cp "$src/pyproject.toml" "$local_rel/"
          printf '    - %s\n' "$local_rel"
        done
      done < <(parse_workspace_members pyproject.toml)
    fi

    printf '  - Creating virtual environment ...\n'
    uv venv
    printf '    Python: %s\n' "$(.venv/bin/python3 --version)"

    printf '  - Exporting requirements from uv.lock ...\n'
    uv export \
      --format requirements-txt \
      --all-packages \
      --all-extras \
      --all-groups \
      --no-emit-workspace \
      --no-emit-local \
      --frozen \
      --no-hashes \
      --no-annotate \
      --quiet \
      -o requirements.txt

  else

    # ── Mode 2: pyproject.toml with named groups via uv pip compile ───────────

    cp /workspace/pyproject.toml .
    strip_local_sources pyproject.toml

    printf '  - Creating virtual environment ...\n'
    uv venv
    printf '    Python: %s\n' "$(.venv/bin/python3 --version)"

    printf '  - Compiling requirements from pyproject.toml ...\n'
    uv pip compile \
      ${DEPENDENCY_GROUPS[@]/#/--group } \
      --all-extras \
      --quiet \
      -o requirements.txt \
      pyproject.toml

    rm pyproject.toml

  fi
else

  # ── Mode 1: requirements.txt ──────────────────────────────────────────────

  cp /workspace/requirements.txt .

  printf '  - Creating virtual environment ...\n'
  uv venv
  printf '    Python: %s\n' "$(.venv/bin/python3 --version)"

fi

printf '\n📦 Installing pip-audit ...\n'
uv pip install --quiet pip-audit

# ── Security scan — OSV (superset of PyPI) + ESMS (independent GHSA curation) ──

VULN_FOUND=false
SOURCE_ERRORED=false
OSV_FAILED=false

run_audit() {
  local source="$1"
  local rc=0
  local stderr_file
  stderr_file=$(mktemp)
  printf '\n🔍 Running pip-audit security scan [%s] ...\n' "$source"
  .venv/bin/pip-audit --no-deps --disable-pip -r requirements.txt -s "$source" \
    2>"$stderr_file" || rc=$?
  grep -v '^WARNING:pip_audit' "$stderr_file" >&2 || true
  if [[ $rc -ne 0 ]] && grep -q '^Traceback' "$stderr_file"; then
    printf '\n⚠️  pip-audit crashed on [%s] source (exit %d) — this is usually an upstream bug.\n' "$source" "$rc"
    SOURCE_ERRORED=true
    rm -f "$stderr_file"
    return 1
  fi
  rm -f "$stderr_file"
  case $rc in
    0) ;;
    1) VULN_FOUND=true ;;
    *)
      printf '\n⚠️  pip-audit crashed on [%s] source (exit %d) — this is usually an upstream bug.\n' "$source" "$rc"
      SOURCE_ERRORED=true
      return 1
      ;;
  esac
}

if ! run_audit osv; then
  OSV_FAILED=true
  printf '    ↳ Falling back to [pypi] source for baseline coverage ...\n'
  run_audit pypi
fi

run_audit esms

printf '\n'
if $VULN_FOUND; then
  printf '‼️  Vulnerabilities found\n\n'
  exit 1
fi
if $SOURCE_ERRORED; then
  printf '⚠️  One or more vulnerability sources failed. Review the output above.\n\n'
  exit 2
fi
printf '✅  Finished! No vulnerabilities found.\n\n'
