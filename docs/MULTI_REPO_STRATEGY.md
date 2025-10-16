# Multi-Repository Branching & Packaging Strategy

## Overview

Restructure the OpenProject ecosystem from git submodules to independent Python packages with proper dependency management.

## Repository Structure

### **Individual Component Repositories**

Each component becomes a standalone repo with its own lifecycle:

```
config-manager/          (separate repo)
deploy-manager/          (separate repo)
prober/                  (separate repo)
control-flow/            (separate repo)
dependency-manager/      (separate repo)
tui-form-designer/       (separate repo)
openproject-orchestrator/ (main repo - depends on above)
```

## Branch Strategy (Applied to ALL Repos)

### **Three-Tier Branch Model**

```
develop (development)
   ↓
   PR with CI tests
   ↓
build (packaging & release automation)
   ↓
   Creates GitHub Release
   ↓
main (production deployment)
```

### **Branch Responsibilities**

#### **1. `develop` Branch (Default)**
- Active development
- All source code, tests, documentation
- Full dev dependencies
- Continuous integration runs tests
- Merges allowed only via PR with passing tests

**Files Present:**
```
src/                    # Source code
tests/                  # Test suite
docs/                   # Documentation
scripts/                # Build/utility scripts
pyproject.toml          # Full dependencies (dev + prod)
.github/workflows/      # CI/CD workflows
README.md               # Development guide
```

#### **2. `build` Branch (Build Automation)**
- **Purpose**: Create distributable packages
- **Trigger**: PR from `develop` after tests pass
- **Actions**:
  1. Run full test suite
  2. Build wheel (`.whl`) and source distribution (`.tar.gz`)
  3. Create GitHub Release with version tag
  4. Attach built artifacts to release
  5. Clean up development files from branch
  6. Optional: Publish to PyPI

**Files Present (Minimal):**
```
.github/workflows/
  build-and-release.yml  # Build automation
scripts/
  build_package.sh       # Local build script
pyproject.toml           # Production dependencies ONLY
README.md                # Installation instructions
LICENSE
```

**What Gets Removed:**
- `tests/` directory
- `docs/` directory (docs go to GitHub Pages or wiki)
- Dev dependencies from `pyproject.toml`
- Build/development scripts
- `.pytest_cache/`, `__pycache__/`, etc.

#### **3. `main` Branch (Production)**
- **Purpose**: Production deployment reference
- **Trigger**: Manual PR from `build` after release validated
- **Contents**: Minimal deployment configuration

**Files Present (Absolute Minimum):**
```
README.md                # Production deployment guide
LICENSE
docker-compose.yml       # If applicable
production_config.yaml   # Production defaults
.github/workflows/
  deploy.yml             # Production deployment automation
```

**What's NOT in main:**
- No source code (users install from releases)
- No tests
- No build scripts
- Just deployment configuration

## Package Management

### **How Dependencies Are Handled**

Instead of git submodules, each repo specifies dependencies in `pyproject.toml`:

#### **Example: config-manager repo**

```toml
# config-manager/pyproject.toml
[project]
name = "openproject-config-manager"
version = "3.0.0"
dependencies = [
    "pydantic>=2.0.0",
    "rich>=13.0.0",
    "python-dotenv>=1.0.0"
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0.0",
    "pytest-cov>=4.0.0",
    "black>=24.0.0",
    "flake8>=7.0.0"
]
```

**Build Process:**
```bash
# On build branch
python -m build
# Creates: dist/openproject_config_manager-3.0.0-py3-none-any.whl

# GitHub Actions creates release
gh release create v3.0.0 dist/*.whl \
  --title "Config Manager v3.0.0" \
  --notes "Release notes"
```

#### **Example: orchestrator repo (consumes packages)**

```toml
# openproject-orchestrator/pyproject.toml
[project]
name = "openproject-orchestrator"
version = "2.0.0"

# Option 1: Install from GitHub Releases (Recommended)
dependencies = [
    "openproject-config-manager @ https://github.com/JustinCBates/config-manager/releases/download/v3.0.0/openproject_config_manager-3.0.0-py3-none-any.whl",
    "openproject-deploy-manager @ https://github.com/JustinCBates/deploy-manager/releases/download/v2.0.0/openproject_deploy_manager-2.0.0-py3-none-any.whl",
    "rich>=13.0.0",
    "click>=8.0.0"
]

# Option 2: Install from PyPI (if published)
dependencies = [
    "openproject-config-manager==3.0.0",
    "openproject-deploy-manager==2.0.0",
    "rich>=13.0.0",
    "click>=8.0.0"
]

# Option 3: Install from Git tags (fallback)
dependencies = [
    "openproject-config-manager @ git+https://github.com/JustinCBates/config-manager.git@v3.0.0",
    "openproject-deploy-manager @ git+https://github.com/JustinCBates/deploy-manager.git@v2.0.0",
    "rich>=13.0.0",
    "click>=8.0.0"
]
```

## Workflow Examples

### **Scenario 1: Update config-manager**

```bash
# In config-manager repo

# 1. Develop feature
git checkout develop
git checkout -b feature/new-validator
# ... make changes ...
git commit -m "feat: add new configuration validator"
git push origin feature/new-validator

# 2. Create PR to develop
gh pr create --base develop --title "Add new validator"
# CI runs tests automatically

# 3. Merge to develop
gh pr merge --merge

# 4. Create PR from develop to build (triggers release)
git checkout develop
git pull
# Bump version in pyproject.toml to 3.1.0
git add pyproject.toml
git commit -m "chore: bump version to 3.1.0"
git push

gh pr create --base build --title "Release v3.1.0"

# 5. Merge to build (triggers GitHub Actions)
gh pr merge --merge
# Actions automatically:
# - Run tests
# - Build wheel
# - Create GitHub Release v3.1.0
# - Attach wheel to release
```

### **Scenario 2: Update orchestrator to use new config-manager**

```bash
# In openproject-orchestrator repo

git checkout develop
git checkout -b deps/update-config-manager

# Update dependency version
# Edit pyproject.toml:
# Change: openproject-config-manager==3.0.0
# To:     openproject-config-manager==3.1.0

git add pyproject.toml
git commit -m "deps: update config-manager to v3.1.0"
git push origin deps/update-config-manager

gh pr create --base develop --title "Update config-manager to v3.1.0"
# CI runs tests with new version

gh pr merge --merge
```

## Migration Steps

### **Phase 1: Separate Repositories**

1. **Create standalone repos** for each submodule:
   ```bash
   # For each submodule
   cd external/config-manager
   gh repo create JustinCBates/config-manager --public --source=. --remote=upstream
   git push upstream develop
   ```

2. **Set up branch structure** in each repo:
   ```bash
   git checkout -b build develop
   git push upstream build
   
   git checkout -b main develop
   git push upstream main
   ```

3. **Add build workflows** to each repo (copy from template)

### **Phase 2: Update Main Repo**

1. **Remove submodules**:
   ```bash
   git rm external/config-manager
   git rm external/deploy-manager
   # ... etc
   ```

2. **Update pyproject.toml** with package dependencies:
   ```toml
   dependencies = [
       "openproject-config-manager==3.0.0",
       "openproject-deploy-manager==2.0.0"
   ]
   ```

3. **Update imports** (should work unchanged if package names match)

### **Phase 3: Establish CI/CD**

1. Add GitHub Actions workflows to all repos
2. Test build process in each repo
3. Create initial releases
4. Verify orchestrator can install dependencies

## Comparison: Linux Package Management

### **How apt/yum Handle Packages**

```bash
# Package repository structure
/var/lib/apt/packages/
  └── python3-requests_2.31.0-1_all.deb
      ├── control (metadata: name, version, dependencies)
      ├── data.tar.gz (actual files)
      └── depends: python3-urllib3, python3-certifi

# When you run:
apt install python3-requests

# apt does:
1. Check /etc/apt/sources.list for repository URLs
2. Download package metadata
3. Resolve dependency tree (requests → urllib3, certifi)
4. Download all required .deb files
5. Extract and install in dependency order
```

### **How pip Handles Packages**

```bash
# PyPI repository structure
https://pypi.org/simple/requests/
  └── requests-2.31.0-py3-none-any.whl
      ├── METADATA (dependencies, version, author)
      └── requests/ (source code)

# When you run:
pip install requests

# pip does:
1. Query PyPI index (https://pypi.org/simple/requests/)
2. Download .whl file
3. Read METADATA for dependencies
4. Recursively install dependencies
5. Extract wheel to site-packages/
```

### **Your Multi-Repo Should Work Like This**

```bash
# Each component repo creates a wheel:
config-manager → openproject_config_manager-3.0.0-py3-none-any.whl
deploy-manager → openproject_deploy_manager-2.0.0-py3-none-any.whl

# Main repo declares dependencies:
# openproject-orchestrator/pyproject.toml
dependencies = [
    "openproject-config-manager==3.0.0",
    "openproject-deploy-manager==2.0.0"
]

# When user installs orchestrator:
pip install openproject-orchestrator

# pip automatically:
1. Resolves: orchestrator needs config-manager==3.0.0
2. Downloads: config-manager wheel from GitHub/PyPI
3. Installs: config-manager first
4. Installs: orchestrator second
```

## Advantages of This Approach

### **1. Clean Dependency Management**
- ✅ No git submodules to sync
- ✅ pip handles version resolution
- ✅ Standard Python packaging (works with pip, poetry, pipenv)

### **2. Independent Development Cycles**
- ✅ config-manager can release v3.1.0 independently
- ✅ orchestrator can stay on config-manager v3.0.0 until ready
- ✅ No coordinated multi-repo commits

### **3. Easier CI/CD**
- ✅ Each repo has own test suite
- ✅ Each repo releases independently
- ✅ Build artifacts stored in GitHub Releases (not git)

### **4. Better for Users**
- ✅ Simple installation: `pip install openproject-orchestrator`
- ✅ Automatic dependency resolution
- ✅ Can install individual components: `pip install openproject-config-manager`

### **5. Production Ready**
- ✅ Only compiled artifacts go to production
- ✅ No source code, tests, or dev tools in deployment
- ✅ Faster installation (wheels are pre-built)

## Disadvantages & Mitigations

### **Concern 1: Need to publish packages somewhere**

**Solutions:**
- Use GitHub Releases (free, integrated)
- Use PyPI (free for open source)
- Run private PyPI server (devpi, artifactory)

### **Concern 2: More repos to manage**

**Mitigations:**
- Automate with GitHub Actions
- Use repo templates for consistency
- Create meta-repo with scripts to manage all

### **Concern 3: Coordinating breaking changes**

**Mitigations:**
- Use semantic versioning strictly
- Test integration in orchestrator CI
- Create compatibility matrix in docs

## Recommended Next Steps

1. **Choose package distribution method**:
   - GitHub Releases (easiest, recommended)
   - PyPI (if open source)
   - Private PyPI server (if proprietary)

2. **Create repo template** with:
   - Three-tier branch structure
   - GitHub Actions workflows
   - Build scripts
   - README templates

3. **Migrate one submodule** as proof of concept:
   - Start with config-manager (most stable)
   - Test full cycle: develop → build → release
   - Update orchestrator to consume package

4. **Roll out to remaining submodules**:
   - Apply template to each
   - Create initial releases
   - Update orchestrator dependencies

5. **Remove git submodules** from main repo

6. **Update documentation** with new workflow

## Questions to Consider

1. **Will packages be open source or private?**
   - Open source → Use PyPI
   - Private → Use GitHub Releases or private PyPI

2. **How often will components release?**
   - Frequently → Automate everything
   - Rarely → Manual releases OK

3. **Do users need individual components?**
   - Yes → Publish all to PyPI
   - No → GitHub Releases sufficient

4. **Need version pinning or ranges?**
   - Pinning: `config-manager==3.0.0` (stability)
   - Ranges: `config-manager>=3.0.0,<4.0.0` (flexibility)

