# OpenProject Development Environment

This is the development branch containing all source code, build tools, and development documentation.

> **End Users:** If you just want to install and use OpenProject, see the [production branch](https://github.com/JustinCBates/openproject-docker-compose/tree/production) for simple installation instructions.

## Development Setup

### Quick Start

```bash
# Clone with all development components
git clone --recursive -b develop https://github.com/JustinCBates/openproject-docker-compose.git
cd openproject-docker-compose

# Run automated development environment setup
./setup-dev-environment.sh

# Open VS Code with multi-repository workspace
code openproject.code-workspace
```

### Repository Architecture

This repository uses a **three-tier branching strategy**:

- **`develop`** - Active development (source code, tests, documentation)
- **`build`** - Automated builds (GitHub Actions creates releases)
- **`production`** - Clean deployment (user installation only)

### Component Structure

```
openproject-docker-compose/
├── external/                   # Git submodules (development only)
│   ├── config-manager/         # Interactive configuration management
│   ├── deploy-manager/         # Deployment utilities
│   ├── control-flow/          # Control flow engine
│   ├── dependency-manager/    # Dependency management
│   ├── tui-form-designer/     # TUI form builder
│   └── prober/               # Docker environment probing (experimental)
├── src/                       # Main orchestrator source
├── tests/                     # Test suites
├── docs/                      # Development documentation
├── scripts/                   # Build and automation scripts
└── pyproject.toml            # Python package configuration
```

### Package Distribution

Components are distributed as **pip-installable packages** via GitHub Releases:

```bash
# Install from releases (production)
pip install https://github.com/user/config-manager/releases/latest/download/package.whl

# Install from local development (development)
pip install -e ./external/config-manager/
```

## Development Workflow

### 1. Component Development

Each `external/` directory is a separate Git repository:

```bash
# Make changes in any component
cd external/config-manager/
# ... make changes ...
git add . && git commit -m "feature: add new capability"
git push origin develop

# Test locally
cd ../../
pip install -e ./external/config-manager/
pytest tests/
```

### 2. Release Workflow

```bash
# 1. Update version in component
cd external/config-manager/
# Edit pyproject.toml version: 2.0.1 -> 2.0.2

# 2. Create changelog
echo "## v2.0.2\n- Feature: New capability" >> CHANGELOG.md

# 3. Commit and merge to build branch
git add . && git commit -m "release: bump version to 2.0.2"
git push origin develop

# 4. Merge develop -> build (triggers GitHub Actions)
git checkout build
git merge develop
git push origin build

# GitHub Actions automatically:
# - Runs tests
# - Builds wheel packages
# - Creates GitHub release
# - Publishes packages
```

### 3. Integration Testing

```bash
# Test with released packages
pip install -r requirements-github.txt

# Test with local development packages
pip install -r requirements-local.txt

# Run full test suite
pytest tests/ external/*/tests/
```

## VS Code Workspace

### Features

- **Multi-Repository Support** - All components as separate folders
- **Integrated Git** - Submodule management
- **Python Development** - Configured paths, linting, formatting
- **Built-in Tasks** - Test, format, lint across all repos
- **Debug Configurations** - Ready-to-use debugging

### Available Tasks

Run from VS Code Command Palette (Ctrl+Shift+P > "Tasks: Run Task"):

- `Run Tests (All Repos)` - Execute pytest across all components
- `Format Code (Black - All Repos)` - Auto-format Python code
- `Lint Code (Flake8 - All Repos)` - Code quality checking
- `Update Submodules` - Sync latest changes from all repos
- `Initialize Submodules (First Time Setup)` - Set up repos for new clones
- `Switch All Submodules to Main Branch` - Prepare for development

## Automation Scripts

### Repository Management

```bash
# Set up build branches for all repositories
scripts/setup_all_build_branches.sh

# Add GitHub Actions workflows to all repositories
scripts/add_workflows_to_submodules.sh

# Verify all repositories are configured correctly
scripts/verify_all_repos.sh
```

### Build and Release

```bash
# Build local packages for testing
python -m build external/config-manager/
python -m build external/deploy-manager/
# ... etc for each component

# Create release packages
scripts/build_all_releases.sh
```

## Documentation

### Architecture Documentation

- [`docs/MULTI_REPO_STRATEGY.md`](docs/MULTI_REPO_STRATEGY.md) - Three-tier branching strategy
- [`docs/PACKAGE_MANAGEMENT_EXPLAINED.md`](docs/PACKAGE_MANAGEMENT_EXPLAINED.md) - Package distribution
- [`docs/ARCHITECTURE_VISUAL.md`](docs/ARCHITECTURE_VISUAL.md) - System architecture
- [`docs/DEVELOPMENT_WORKSPACE_SETUP.md`](docs/DEVELOPMENT_WORKSPACE_SETUP.md) - Development environment

### Integration Guides

- [`docs/GITHUB_PIP_INTEGRATION.md`](docs/GITHUB_PIP_INTEGRATION.md) - GitHub releases + pip
- [`docs/QUICK_REFERENCE.md`](docs/QUICK_REFERENCE.md) - Command quick reference

### Build System

- [`docs/BUILD_BRANCH_SETUP_COMPLETE.md`](docs/BUILD_BRANCH_SETUP_COMPLETE.md) - Build configuration
- [`docs/REPOSITORY_STATUS_REPORT.md`](docs/REPOSITORY_STATUS_REPORT.md) - Repository status
- [`docs/MULTI_REPO_BUILD_SYSTEM_COMPLETE.md`](docs/MULTI_REPO_BUILD_SYSTEM_COMPLETE.md) - Complete build system

## Testing

### Running Tests

```bash
# All tests across all repositories
pytest

# Specific component tests
pytest external/config-manager/tests/
pytest tests/test_integration.py

# With coverage
pytest --cov=src --cov-report=html
```

### Test Structure

```
tests/
├── test_integration.py        # Cross-component integration
├── test_orchestrator.py       # Main orchestrator
└── test_deployment.py         # End-to-end deployment

external/*/tests/              # Component-specific tests
```

## Contributing

### Code Standards

- **Python:** Black formatting, Flake8 linting, mypy type checking
- **Commits:** Conventional commits (`feat:`, `fix:`, `docs:`)
- **Testing:** Minimum 80% test coverage
- **Documentation:** All public APIs documented

### Pull Request Process

1. **Fork and branch** from `develop`
2. **Make changes** in appropriate component repositories
3. **Test locally** with `pytest` and automation scripts
4. **Update documentation** if needed
5. **Submit PR** to `develop` branch

### Development Environment Requirements

```bash
# Python 3.9+
python --version

# Development tools (installed by setup-dev-environment.sh)
pip install black flake8 mypy pytest pytest-cov

# Container tools
docker --version
docker-compose --version

# VS Code (recommended)
code --version
```

## Release Management

### Current Versions

- config-manager: v2.0.1
- deploy-manager: v2.1.0
- control-flow: v0.2.0
- dependency-manager: v0.2.0
- tui-form-designer: v1.0.1
- prober: v0.1.0 (⚠️ experimental)

### Release Status

Check GitHub Actions for build status:
- [config-manager builds](https://github.com/JustinCBates/openproject-config-manager/actions)
- [deploy-manager builds](https://github.com/JustinCBates/openproject-deploy-manager/actions)
- [control-flow builds](https://github.com/JustinCBates/control-flow/actions)
- [dependency-manager builds](https://github.com/JustinCBates/dependency-manager/actions)
- [tui-form-designer builds](https://github.com/JustinCBates/TUI_Form_Designer/actions)

## Troubleshooting

### Common Development Issues

**Submodule out of sync:**
```bash
git submodule update --remote --merge
```

**Build failures:**
```bash
# Check individual component
cd external/config-manager/
python -m build
pytest

# Check GitHub Actions logs
```

**Import errors in development:**
```bash
# Install in development mode
pip install -e ./external/config-manager/
pip install -e ./external/deploy-manager/
# ... etc
```

### Getting Help

- **Issues:** [GitHub Issues](https://github.com/JustinCBates/openproject-docker-compose/issues)
- **Discussions:** [GitHub Discussions](https://github.com/JustinCBates/openproject-docker-compose/discussions)
- **Documentation:** [`docs/`](docs/) directory

---

**Remember:** This branch contains the complete development environment. For simple OpenProject installation, users should use the [production branch](https://github.com/JustinCBates/openproject-docker-compose/tree/production).