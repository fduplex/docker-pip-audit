# docker-pip-audit

A containerized [pip-audit](https://github.com/pypa/pip-audit) security scanner for Python projects. Runs vulnerability scans in an isolated Docker environment without polluting your local system.

## Features

- Scans Python dependencies for known security vulnerabilities
- Supports both `requirements.txt` and `pyproject.toml` workflows
- Isolated environment - no local Python installation required
- Uses [uv](https://github.com/astral-sh/uv) for fast, reliable dependency resolution

## Installation

### 1. Build the Docker image

```bash
docker build -t docker-pip-audit:latest .
```

### 2. Create a shell alias

Add this alias to your shell configuration (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
alias pip-audit='docker run --rm -t -v "$(pwd):/workspace:ro" docker-pip-audit:latest'
```

Reload your shell or run `source ~/.bashrc` (or equivalent) to apply.

## Usage

Navigate to any Python project directory containing a `requirements.txt` or `pyproject.toml` file and run:

```bash
pip-audit
```

The tool will automatically:
1. Detect your dependency file (`requirements.txt` or `pyproject.toml`)
2. Create an isolated virtual environment
3. Install your dependencies
4. Run `pip-audit` to scan for vulnerabilities

## Supported Workflows

### requirements.txt

When a `requirements.txt` file is detected, the tool uses the Python version bundled with the base image (Debian Trixie).

### pyproject.toml

When a `pyproject.toml` file is detected:
- The file is compiled to `requirements.txt` using `uv pip compile`
- If a Python version is specified in your `pyproject.toml` (e.g., `requires-python`), uv will enforce that version
- If no Python version is specified, the distro-included Python from the base image is used

## Example Output

```
🐳 Created isolated docker Python environment for pip-audit

🛠️  Preparing shadow project folder with file:[requirements.txt]...
  - Creating virtual environment ... done! (Python 3.12.x)
  - Installing pip-audit ... done!

📦 Installing Python requirements ...

🔍 Running pip-audit security scan ...
No known vulnerabilities found

Finished!
```

## License

Apache License 2.0 - See [LICENSE](LICENSE) for details.
