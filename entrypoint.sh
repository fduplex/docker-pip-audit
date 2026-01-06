#!/usr/bin/env bash
set -e

printf '\n🐳 Created isolated docker Python environment for pip-audit\n\n'

if [[ -r /workspace/requirements.txt ]]; then
  REQUIREMENTS="requirements.txt"
elif [[ -r /workspace/pyproject.toml ]]; then
  REQUIREMENTS="pyproject.toml"
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
printf "done! ($(python3 --version))\n"

if [[ $REQUIREMENTS == "pyproject.toml" ]]; then
  printf -- '  - Compiling requirements.txt from pyproject.toml ... '
  uv pip compile -o requirements.txt pyproject.toml 1>/dev/null
  rm pyproject.toml
  printf "done!\n"
fi

printf -- "  - Installing pip-audit ... "
uv pip install pip-audit --quiet
printf "done!\n"

printf "\n📦 Installing Python requirements ...\n"
uv pip install -r requirements.txt

printf '\n🔍 Running pip-audit security scan ...\n'
uv run pip-audit --skip-editable

printf '\nFinished!\n\n'
exit
