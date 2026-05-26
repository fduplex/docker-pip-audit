# docker-pip-audit

A containerized [pip-audit](https://github.com/pypa/pip-audit) security scanner for Python projects. Runs vulnerability scans in an isolated Docker environment without polluting your local system.

## Features

- Scans Python dependencies against two independent vulnerability databases (OSV + ESMS) for ~98% coverage
- Falls back to PyPI source automatically if OSV is unavailable
- Supports `requirements.txt`, `pyproject.toml`, and uv workspace projects
- `pip-audit all` — scans every dependency group and every workspace member in one shot
- Auto-detects and downloads the correct Python version from `requires-python`
- Uses [uv](https://github.com/astral-sh/uv) for fast, reliable dependency resolution
- No packages are installed into the container — scans pinned requirements files directly
- Host CLI (`pip-audit.sh`) with `build`, `update`, and `version` commands for image lifecycle

## Installation

### 1. Clone and build

```bash
git clone git@github.com:fduplex/docker-pip-audit.git ~/docker-pip-audit
cd ~/docker-pip-audit
./pip-audit.sh build
```

### 2. Add a shell alias

```bash
alias pip-audit='~/docker-pip-audit/pip-audit.sh'
```

Add to your `~/.bashrc` / `~/.zshrc` and reload.

## Usage

Navigate to any Python project and run:

```bash
pip-audit              # scan main dependencies
pip-audit dev test     # include specific dependency groups
pip-audit all          # scan all groups + all workspace members
```

### Vulnerability sources

Every scan runs against two databases in series:

| Source | What it covers |
|--------|---------------|
| **osv** | Open Source Vulnerabilities API — aggregates PyPI advisories, GHSA, NVD, and PSF. Best single-source coverage (~93%). |
| **esms** | Ecosyste.ms — independently curated GHSA pipeline. Accretive to OSV; combined coverage reaches ~98%. |

If OSV crashes (e.g. due to an upstream bug in pip-audit), the scanner falls back to the **pypi** source for baseline coverage, then continues with ESMS.

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | No vulnerabilities found |
| 1 | Vulnerabilities found |
| 2 | One or more vulnerability sources failed (review output) |

## Supported project types

### `requirements.txt`

Detected automatically. pip-audit reads the file directly — no compilation or installation needed.

### `pyproject.toml` (named groups)

```bash
pip-audit              # main dependencies + all extras
pip-audit dev          # main + dev group
pip-audit dev test     # main + dev + test groups
```

Uses `uv pip compile` to produce a fully-pinned requirements file, then scans it without installing. Local/private sources (`[tool.uv.sources]`) are stripped automatically.

### `pyproject.toml` (all groups + workspace)

```bash
pip-audit all
```

Requires a `uv.lock` file (always committed in uv projects; run `uv lock` first if missing). Uses `uv export` to produce a single flat requirements file covering:

- Every dependency group across the project
- Every workspace member (for [uv workspaces](https://docs.astral.sh/uv/concepts/workspaces/))

Example workspace layout:

```
my-project/
├── pyproject.toml        # [tool.uv.workspace] members = ["api", "worker"]
├── uv.lock
├── api/
│   └── pyproject.toml
└── worker/
    └── pyproject.toml
```

Running `pip-audit all` from `my-project/` scans all three projects in one invocation.

## Image management

### Build

```bash
pip-audit build
```

Builds the Docker image using the version pins in `versions`.

### Update

```bash
pip-audit update
```

When `UV_VERSION=latest` (the default), rebuilds with `--pull` to fetch the newest uv image from GitHub Container Registry.

When `UV_VERSION` is pinned to an explicit version (e.g. `0.7.5`), `update` refuses and tells you to edit `versions` instead — no silent upgrades.

### Version info

```bash
pip-audit version
```

Shows the configured `UV_VERSION` and the actual uv version built into the current image.

### Version pinning

Edit `versions` to pin uv to a specific release:

```bash
UV_VERSION=0.7.5      # pin to explicit version
# UV_VERSION=latest   # float (default)
```

Then rebuild: `pip-audit build`.

## Example output

```
🐳 docker-pip-audit

🛠️  Preparing shadow project [pyproject.toml] ...
  - Creating virtual environment ...
    Python: Python 3.11.15
  - Compiling requirements from pyproject.toml ...

📦 Installing pip-audit ...

🔍 Running pip-audit security scan [osv] ...
No known vulnerabilities found

🔍 Running pip-audit security scan [esms] ...
No known vulnerabilities found

✅  Finished! No vulnerabilities found.
```

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.
