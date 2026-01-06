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

  printf -- '  - Stripping local/private sources from pyproject.toml ... \n'

  # Extract package names from [tool.uv.sources] section
  local local_packages
  local_packages=$(awk '
    /^\[tool\.uv\.sources\]/ { in_section=1; next }
    /^\[/ { in_section=0 }
    in_section && /^[a-zA-Z0-9_-]+[ ]*=/ { 
      gsub(/[ ]*=.*/, ""); 
      print 
    }
  ' "$file")

  # Build awk pattern to remove these packages from dependencies array
  # Matches: "package-name", "package-name>=1.0", "package-name[extra]", etc.
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
    printf -- "    - Skipped packages: %s\n" "$(echo $local_packages | tr '\n' ' ')"
  fi
}

# --- Main ---

printf '\n🐳 Created isolated docker Python environment for pip-audit\n\n'

DEPENDENCY_GROUPS=""
if [[ -r /workspace/pyproject.toml ]]; then
  REQUIREMENTS="pyproject.toml"

  if [[ $# -ge 1 ]]; then DEPENDENCY_GROUPS=("$@"); fi

elif [[ -r /workspace/requirements.txt ]]; then
  REQUIREMENTS="requirements.txt"
else
  printf '‼️  This utility requires a [pyproject.toml] or [requirements.txt] file in the working directory.\n\n'
  exit 1
fi

printf "🛠️  Preparing shadow project folder with file:[$REQUIREMENTS]...\n"
mkdir /project
cp "/workspace/$REQUIREMENTS" /project/
cd /project

printf -- "  - Creating virtual environment ... "
uv venv --quiet
printf "done! ($(.venv/bin/python3 --version))\n"

if [[ $REQUIREMENTS == "pyproject.toml" ]]; then
  strip_local_sources pyproject.toml

  printf -- '  - Compiling requirements.txt from pyproject.toml ... '
  uv pip compile ${DEPENDENCY_GROUPS[@]/#/--group } --all-extras -o requirements.txt pyproject.toml --quiet
  rm pyproject.toml
  printf "done!\n"
fi

printf -- "  - Installing pip-audit ... "
uv pip install pip-audit --quiet
printf "done!\n"

printf "\n📦 Installing Python requirements ...\n"
uv pip install -r requirements.txt

printf '\n🔍 Running pip-audit security scan ...\n'
uv run pip-audit --skip-editable && printf '\n✅  Finished!\n\n' || {
  printf '\n‼️  Vulnerabilities Found\n\n'
  exit 1
}

exit
