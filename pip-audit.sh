#!/usr/bin/env bash
set -e

# shellcheck disable=SC2317
DOC="docker-pip-audit — Containerized pip-audit security scanner.

Usage:
  pip-audit all
  pip-audit build
  pip-audit update
  pip-audit version
  pip-audit (-h | --help)
  pip-audit [<group>...]

Options:
  -h --help   Show this message.

Examples:
  pip-audit               Scan default dependencies
  pip-audit dev test      Scan with dev and test dependency groups
  pip-audit all           Scan all groups + workspace members (requires uv.lock)
  pip-audit build         Build the Docker image
  pip-audit update        Rebuild image to refresh uv (when UV_VERSION=latest)
"
# docopt parser below, refresh this parser with `docopt.sh pip-audit.sh`
# shellcheck disable=2016,2086,2329,1075,2154
docopt() { parse() { if ${DOCOPT_DOC_CHECK:-true}; then local doc_hash;if \
doc_hash=$(printf "%s" "$DOC" | (sha256sum 2>/dev/null || shasum -a 256)); then
if [[ ${doc_hash:0:5} != "$digest" ]]; then stderr "The current usage doc \
(${doc_hash:0:5}) does not match what the parser was generated with (${digest})
Run \`docopt.sh\` to refresh the parser.";_return 70;fi;fi;fi;local root_idx=$1
shift;params=();testdepth=0;local argv=("$@") arg i o;while [[ ${#argv[@]} -gt \
0 ]]; do if [[ ${argv[0]} = "--" ]]; then for arg in "${argv[@]}"; do
params+=("a:$arg");done;break;elif [[ ${argv[0]} = --* ]]; then local \
long=${argv[0]%%=*};if ${DOCOPT_ADD_HELP:-true} && [[ $long = "--help" ]]; then
stdout "$trimmed_doc";_return 0;elif [[ ${DOCOPT_PROGRAM_VERSION:-false} != 'f'\
'alse' && $long = "--version" ]]; then stdout "$DOCOPT_PROGRAM_VERSION"
_return 0;fi;local similar=() match=false;i=0;for o in "${options[@]}"; do if \
[[ $o = *" $long "? ]]; then similar+=("$long");match=$i;break;fi;: $((i++))
done;if [[ $match = false ]]; then i=0;for o in "${options[@]}"; do if [[ $o = \
*" $long"*? ]]; then local long_match=${o#* };similar+=("${long_match% *}")
match=$i;fi;: $((i++));done;fi;if [[ ${#similar[@]} -gt 1 ]]; then error \
"${long} is not a unique prefix: ${similar[*]}?";elif [[ ${#similar[@]} -lt 1 \
]]; then error;else if [[ ${options[$match]} = *0 ]]; then if [[ ${argv[0]} = \
*=* ]]; then local long_match=${o#* };error "${long_match% *} must not have an \
argument";else params+=("$match:true");argv=("${argv[@]:1}");fi;else if [[ \
${argv[0]} = *=* ]]; then params+=("$match:${argv[0]#*=}");argv=("${argv[@]:1}")
else if [[ ${#argv[@]} -le 1 || ${argv[1]} = '--' ]]; then error "${long} \
requires argument";fi;params+=("$match:${argv[1]}");argv=("${argv[@]:2}");fi;fi
fi;elif [[ ${argv[0]} = -* && ${argv[0]} != "-" ]]; then local \
remaining=${argv[0]#-};while [[ -n $remaining ]]; do local \
short="-${remaining:0:1}";if ${DOCOPT_ADD_HELP:-true} && [[ $short = "-h" ]]; \
then stdout "$trimmed_doc";_return 0;fi;local matched=false
remaining="${remaining:1}";i=0;for o in "${options[@]}"; do if [[ $o = "$short \
"* ]]; then if [[ $o = *1 ]]; then if [[ $remaining = '' ]]; then if [[ \
${#argv[@]} -le 1 || ${argv[1]} = '--' ]]; then error "${short} requires \
argument";fi;params+=("$i:${argv[1]}");argv=("${argv[@]:1}");break 2;else
params+=("$i:$remaining");break 2;fi;else params+=("$i:true");matched=true;break
fi;fi;: $((i++));done;$matched || error;done;argv=("${argv[@]:1}");elif \
${DOCOPT_OPTIONS_FIRST:-false}; then for arg in "${argv[@]}"; do
params+=("a:$arg");done;break;else params+=("a:${argv[0]}")
argv=("${argv[@]:1}");fi;done;if ! "node_$root_idx" || [ ${#params[@]} -gt 0 \
]; then error;fi;return 0;};choice() { local initial_params=("${params[@]}") \
best_match_idx unmatched_count node_idx;: $((testdepth++));for node_idx in \
"$@"; do if "node_$node_idx"; then if [[ -z $unmatched_count || ${#params[@]} \
-lt $unmatched_count ]]; then best_match_idx=$node_idx
unmatched_count=${#params[@]};fi;fi;params=("${initial_params[@]}");done;: \
$((testdepth--));if [[ -n $best_match_idx ]]; then "node_$best_match_idx"
return 0;fi;return 1;};optional() { local node_idx;for node_idx in "$@"; do
"node_$node_idx";done;return 0;};repeatable() { local matched=false \
remaining=${#params[@]};while "node_$1"; do matched=true;[[ $remaining -eq \
${#params[@]} ]] && break;remaining=${#params[@]};done;if $matched; then
return 0;fi;return 1;};switch() { local i param;for i in "${!params[@]}"; do
local param=${params[$i]};if [[ $param = "$2" || $param = "$2":* ]]; then
params=("${params[@]:0:$i}" "${params[@]:((i+1))}");[[ $testdepth -gt 0 ]] && \
return 0;if [[ $3 = true ]]; then eval "((var_$1++))" || true;else eval \
"var_$1=true";fi;return 0;elif [[ $param = a:* && $2 = a:* ]]; then return 1;fi
done;return 1;};value() { local i param;for i in "${!params[@]}"; do local \
param=${params[$i]};if [[ $param = "$2":* ]]; then params=("${params[@]:0:$i}" \
"${params[@]:((i+1))}");[[ $testdepth -gt 0 ]] && return 0;local value
value=$(printf -- "%q" "${param#*:}");if [[ $3 = true ]]; then eval \
"var_$1+=($value)";else eval "var_$1=$value";fi;return 0;fi;done;return 1;}
stdout() { printf -- "cat <<'EOM'\n%s\nEOM\n" "$1";};stderr() { printf -- "cat \
<<'EOM' >&2\n%s\nEOM\n" "$1";};error() { [[ -n $1 ]] && stderr "$1";stderr \
"$usage";_return 1;};_return() { printf -- "exit %d\n" "$1";exit "$1";};set -e
trimmed_doc=${DOC:0:574};usage=${DOC:62:130};digest=08cdc;options=('-h --help '\
'0');node_0(){ switch __help 0;};node_1(){ value _group_ a true;};node_2(){
switch all a:all;};node_3(){ switch build a:build;};node_4(){ switch update \
a:update;};node_5(){ switch version a:version;};node_6(){ optional 7;};node_7(){
repeatable 1;};node_8(){ choice 2 3 4 5 0 6;};cat <<<' docopt_exit() { [[ -n \
$1 ]] && printf "%s\n" "$1" >&2;printf "%s\n" "${DOC:62:130}" >&2;exit 1;}'
local varnames=(__help _group_ all build update version) varname;for varname \
in "${varnames[@]}"; do unset "var_$varname";done;parse 8 "$@";local \
p=${DOCOPT_PREFIX:-''};for varname in "${varnames[@]}"; do unset "$p$varname"
done;if declare -p var__group_ >/dev/null 2>&1; then eval $p'_group_=("${var__'\
'group_[@]}")';else eval $p'_group_=()';fi;eval $p'__help=${var___help:-false}'\
';'$p'all=${var_all:-false};'$p'build=${var_build:-false};'$p'update=${var_upd'\
'ate:-false};'$p'version=${var_version:-false};';local docopt_i=1;[[ \
$BASH_VERSION =~ ^4.3 ]] && docopt_i=2;for ((;docopt_i>0;docopt_i--)); do for \
varname in "${varnames[@]}"; do declare -p "$p$varname";done;done;}
# docopt parser above, complete command for generating this parser is `docopt.sh pip-audit.sh`
eval "$(docopt "$@")"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

load_versions() {
  local vf="$SCRIPT_DIR/versions"
  if [[ ! -f "$vf" ]]; then
    printf 'Error: versions file not found at %s\n' "$vf" >&2
    exit 1
  fi
  # shellcheck source=versions
  source "$vf"
}

check_docker() {
  if ! docker info &>/dev/null; then
    printf 'Error: Docker is not running or not accessible.\n' >&2
    exit 1
  fi
}

cmd_scan() {
  load_versions
  check_docker
  local docker_args=()
  if [[ "$all" == "true" ]]; then
    docker_args+=("--all")
  else
    docker_args+=("${_group_[@]+"${_group_[@]}"}")
  fi
  docker run --rm -t -v "$(pwd):/workspace:ro" "${IMAGE_NAME}:latest" "${docker_args[@]+"${docker_args[@]}"}"
}

cmd_build() {
  load_versions
  check_docker
  printf 'Building %s ...\n' "$IMAGE_NAME"
  printf '  uv: %s\n' "$UV_VERSION"
  docker build --build-arg "UV_VERSION=${UV_VERSION}" -t "${IMAGE_NAME}:latest" "$SCRIPT_DIR"
  printf 'Done.\n'
}

cmd_update() {
  load_versions
  check_docker
  case "$UV_VERSION" in
    latest)
      printf 'Updating %s (uv channel: latest) ...\n' "$IMAGE_NAME"
      docker build --pull --build-arg "UV_VERSION=${UV_VERSION}" -t "${IMAGE_NAME}:latest" "$SCRIPT_DIR"
      printf 'Done.\n'
      ;;
    *)
      printf 'uv is pinned to %s in versions — refusing silent upgrade.\n' "$UV_VERSION" >&2
      printf 'Edit %s/versions and change UV_VERSION, then run: pip-audit build\n' "$SCRIPT_DIR" >&2
      exit 1
      ;;
  esac
}

cmd_version() {
  load_versions
  check_docker
  printf 'Image:       %s:latest\n' "$IMAGE_NAME"
  printf 'UV_VERSION:  %s (configured)\n' "$UV_VERSION"
  if docker image inspect "${IMAGE_NAME}:latest" &>/dev/null; then
    printf 'uv (built):  '
    docker run --rm --entrypoint uv "${IMAGE_NAME}:latest" --version
  else
    printf 'Image not built yet. Run: pip-audit build\n'
  fi
}

if   [[ "$build"   == "true" ]]; then cmd_build
elif [[ "$update"  == "true" ]]; then cmd_update
elif [[ "$version" == "true" ]]; then cmd_version
else                                  cmd_scan
fi
