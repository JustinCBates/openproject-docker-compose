# OpenProject Orchestrator - Build Branch

⚠️ **This is the BUILD branch** - Used for creating releases and packaged distributions.

## Purpose

This branch is part of a three-tier branching strategy:

```
develop  → Active development (full source, tests, docs)
   ↓ PR
build    → Packaging & releases (creates wheels, GitHub releases)  ← YOU ARE HERE
   ↓ PR
main     → Production deployment (deployment config only)
```

## What This Branch Does

When code is merged to this branch via PR from `develop`:

1. **GitHub Actions** automatically:
   - Runs the full test suite
   - Builds Python wheel packages (`.whl`)
   - Creates a GitHub Release with version tag
   - Attaches built artifacts to the release
   - Optionally publishes to PyPI

2. **Result**: Users can install via pip:
   ```bash
   pip install openproject-orchestrator
   ```

## Workflows

### CI/CD Workflows

- `.github/workflows/build-and-release.yml` - Builds packages and creates releases

### Build Scripts

- `scripts/build_package.sh` - Local build script for testing
- `scripts/extract_submodule.sh` - Migration helper for converting submodules

## Branch Rules

### ⚠️ Important

- **Never commit directly** to this branch
- **Always use PR** from `develop` branch
- **Tests must pass** before merge
- **Version must be bumped** in `pyproject.toml` before creating release

### Merge Process

```bash
# 1. Ensure develop is ready
git checkout develop
git pull origin develop

# 2. Update version in pyproject.toml
# Edit version = "2.1.0" (for example)
git add pyproject.toml
git commit -m "chore: bump version to 2.1.0"
git push origin develop

# 3. Create PR from develop to build
gh pr create --base build --title "Release v2.1.0"

# 4. Wait for CI to pass
# Review the PR

# 5. Merge to build
gh pr merge --merge

# 6. GitHub Actions automatically:
#    - Builds wheel
#    - Creates release v2.1.0
#    - Attaches wheel to release
```

## What's Different from Develop Branch

### Files Present

- ✅ `pyproject.toml` - **Production dependencies only** (no dev deps)
- ✅ `.github/workflows/` - Build automation
- ✅ `scripts/build_package.sh` - Build scripts
- ✅ `README.md` - This file (installation instructions)
- ✅ `LICENSE` - License file

### Files Removed (After Release)

After a successful release, the workflow may clean up:
- ❌ `tests/` - Test suite (not needed in distribution)
- ❌ `docs/` - Development documentation
- ❌ Extra scripts
- ❌ Development tooling configs

Users get these files from GitHub Releases, not from cloning this branch.

## Installing Built Packages

### For Users

```bash
# Latest release
pip install openproject-orchestrator

# Specific version
pip install openproject-orchestrator==2.0.0

# From GitHub release directly
pip install https://github.com/JustinCBates/openproject-docker-compose/releases/download/v2.0.0/openproject_orchestrator-2.0.0-py3-none-any.whl
```

### For Developers

Developers should work on the `develop` branch:

```bash
# Clone the repo
git clone https://github.com/JustinCBates/openproject-docker-compose.git
cd openproject-docker-compose

# Checkout develop
git checkout develop

# Install in editable mode
pip install -e .

# Make changes, test, create PR to develop
```

## Testing a Build Locally

```bash
# Switch to build branch
git checkout build

# Run build script
./scripts/build_package.sh

# Test the built wheel
pip install dist/openproject_orchestrator-*.whl

# Or install in a test environment
python -m venv test-env
source test-env/bin/activate
pip install dist/openproject_orchestrator-*.whl
openproject-orchestrator --version
```

## Current Version

Check `pyproject.toml` for the current version:
```bash
grep "^version" pyproject.toml
```

## Releases

All releases are available at:
https://github.com/JustinCBates/openproject-docker-compose/releases

Each release includes:
- Python wheel (`.whl`) - Recommended for installation
- Source distribution (`.tar.gz`) - For advanced users
- Release notes - Changelog and installation instructions

## Related Documentation

For more information about the branching strategy and packaging:

- [Multi-Repo Strategy](docs/MULTI_REPO_STRATEGY.md)
- [Package Management Explained](docs/PACKAGE_MANAGEMENT_EXPLAINED.md)
- [GitHub pip Integration](docs/GITHUB_PIP_INTEGRATION.md)
- [Quick Reference](docs/QUICK_REFERENCE.md)

## Support

For issues or questions:
- **Development**: Open an issue on the `develop` branch
- **Releases**: Check existing releases or create an issue
- **Installation**: See installation docs in releases

---

**Note**: This branch should remain stable. All active development happens on `develop`.
