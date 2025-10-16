# How Linux Package Managers Handle Python - Applied to Your Repos

## The Answer: pip Works Like apt/yum

When you run `pip install requests`, here's what happens:

```bash
1. pip queries PyPI: "Where is requests?"
   → https://pypi.org/simple/requests/

2. pip downloads metadata (METADATA file):
   Name: requests
   Version: 2.31.0
   Requires-Dist: urllib3>=1.21.1,<3
   Requires-Dist: certifi>=2017.4.17
   Requires-Dist: charset-normalizer>=2,<4

3. pip resolves dependencies:
   requests → needs urllib3, certifi, charset-normalizer

4. pip downloads wheels:
   requests-2.31.0-py3-none-any.whl
   urllib3-2.0.0-py3-none-any.whl
   certifi-2023.7.22-py3-none-any.whl
   charset_normalizer-3.2.0-py3-none-any.whl

5. pip installs in dependency order:
   a. certifi → site-packages/certifi/
   b. charset-normalizer → site-packages/charset_normalizer/
   c. urllib3 → site-packages/urllib3/
   d. requests → site-packages/requests/

6. pip creates .dist-info directories:
   site-packages/requests-2.31.0.dist-info/
     ├── METADATA (dependency info)
     ├── RECORD (installed files)
     ├── WHEEL (build info)
     └── top_level.txt (import names)
```

## Your Architecture Should Be:

### **Don't Use Git Submodules - Use Python Packages**

**Current (submodules):**
```
openproject-orchestrator/
  ├── external/
  │   ├── config-manager/     ← git submodule
  │   ├── deploy-manager/     ← git submodule
  │   └── prober/             ← git submodule
  └── src/
      └── openproject_orchestrator/
          └── __init__.py
              # Adds sys.path for submodules 😞
```

**Recommended (packages):**
```
# Each component is a separate repo with its own releases

config-manager repo:
  → Builds: openproject_config_manager-3.0.0-py3-none-any.whl
  → Published to: GitHub Releases or PyPI

deploy-manager repo:
  → Builds: openproject_deploy_manager-2.0.0-py3-none-any.whl
  → Published to: GitHub Releases or PyPI

orchestrator repo:
  pyproject.toml:
    dependencies = [
        "openproject-config-manager==3.0.0",
        "openproject-deploy-manager==2.0.0"
    ]
  
  → pip automatically installs dependencies
  → No sys.path manipulation needed ✅
```

## Practical Example: Your Exact Setup

### **Step 1: config-manager becomes independent package**

**config-manager repo (separate from orchestrator):**

```toml
# pyproject.toml
[build-system]
requires = ["setuptools>=68.0.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "openproject-config-manager"
version = "3.0.0"
description = "Configuration manager for OpenProject"
requires-python = ">=3.11"
dependencies = [
    "pydantic>=2.0.0",
    "rich>=13.0.0",
    "python-dotenv>=1.0.0"
]

[project.scripts]
openproject-config = "openproject_config_manager.cli:main"
```

**Branch workflow:**
```bash
# develop → feature development
# build → creates wheel & GitHub release
# main → production reference
```

**GitHub Actions (.github/workflows/release.yml):**
```yaml
name: Release Package

on:
  push:
    branches: [build]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build wheel
        run: |
          pip install build
          python -m build
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: v3.0.0
          files: dist/*.whl
```

**Result:** https://github.com/JustinCBates/config-manager/releases/download/v3.0.0/openproject_config_manager-3.0.0-py3-none-any.whl

### **Step 2: orchestrator consumes config-manager package**

**openproject-orchestrator/pyproject.toml:**

```toml
[project]
name = "openproject-orchestrator"
version = "2.0.0"
dependencies = [
    # Option A: From GitHub Releases (Recommended for private repos)
    "openproject-config-manager @ https://github.com/JustinCBates/config-manager/releases/download/v3.0.0/openproject_config_manager-3.0.0-py3-none-any.whl",
    
    # Option B: From PyPI (if published publicly)
    # "openproject-config-manager==3.0.0",
    
    # Option C: From Git (fallback, not recommended)
    # "openproject-config-manager @ git+https://github.com/JustinCBates/config-manager.git@v3.0.0",
    
    "rich>=13.0.0",
    "click>=8.0.0"
]
```

**Installation process:**
```bash
# User installs orchestrator
pip install openproject-orchestrator

# pip automatically:
# 1. Reads orchestrator's dependencies
# 2. Downloads config-manager wheel from GitHub
# 3. Installs config-manager first
# 4. Then installs orchestrator

# Result in site-packages/:
# ├── openproject_config_manager/
# │   └── __init__.py
# ├── openproject_config_manager-3.0.0.dist-info/
# │   └── METADATA
# ├── openproject_orchestrator/
# │   └── __init__.py
# └── openproject_orchestrator-2.0.0.dist-info/
#     └── METADATA
```

**Code works unchanged:**
```python
# src/openproject_orchestrator/coordinators/config_coordinator.py

# This import now works automatically via pip!
from openproject_config_manager import ConfigurationManager

# No sys.path manipulation needed!
# No submodule syncing needed!
# No development mode detection needed!
```

## How This Mirrors Linux Package Management

### **apt (Debian/Ubuntu)**

```bash
# When you run:
apt install python3-requests

# apt does:
1. Check /etc/apt/sources.list for repository URL
   → http://archive.ubuntu.com/ubuntu/

2. Download package metadata (.deb control file)
   Package: python3-requests
   Depends: python3-urllib3, python3-certifi

3. Resolve dependencies recursively

4. Download all .deb files from repository

5. Install in dependency order
   → /usr/lib/python3/dist-packages/requests/
```

### **pip (Python)**

```bash
# When you run:
pip install openproject-orchestrator

# pip does:
1. Check pip index (PyPI or GitHub URL from pyproject.toml)
   → https://github.com/JustinCBates/.../releases/

2. Download package metadata (METADATA from wheel)
   Name: openproject-orchestrator
   Requires-Dist: openproject-config-manager==3.0.0

3. Resolve dependencies recursively

4. Download all .whl files from releases/PyPI

5. Install in dependency order
   → site-packages/openproject_orchestrator/
```

**They work exactly the same way!**

## Advantages for Your Multi-Repo Setup

### **1. No Git Submodule Hell**
```bash
# Before (submodules):
git clone openproject-orchestrator
git submodule init
git submodule update --recursive
cd external/config-manager
git checkout main
cd ../..
# Repeat for 6 submodules... 😞

# After (packages):
pip install openproject-orchestrator
# Done! ✅
```

### **2. Independent Release Cycles**

```bash
# config-manager can release v3.1.0
# deploy-manager stays at v2.0.0
# orchestrator decides when to upgrade

# No need to coordinate commits across repos!
```

### **3. Semantic Versioning**

```toml
# Orchestrator can specify version ranges
dependencies = [
    "openproject-config-manager>=3.0.0,<4.0.0",  # Any 3.x version
    "openproject-deploy-manager==2.0.0"           # Exact version
]

# pip automatically picks latest compatible versions
```

### **4. Standard Python Packaging**

```bash
# Works with all Python tools:
pip install openproject-orchestrator
poetry add openproject-orchestrator
pipenv install openproject-orchestrator
conda install openproject-orchestrator

# Works in virtual envs, docker, CI/CD, everywhere!
```

### **5. Build Branch Makes Sense**

```
develop branch:
  ├── src/                    # Source code
  ├── tests/                  # Tests
  ├── docs/                   # Documentation
  └── pyproject.toml          # Full dependencies

         ↓ PR (after tests pass)

build branch:
  ├── Runs CI
  ├── Builds wheel: openproject_config_manager-3.0.0-py3-none-any.whl
  ├── Creates GitHub Release v3.0.0
  └── Attaches wheel to release

         ↓ Users download from release

Production:
  pip install openproject-config-manager
  # Downloads wheel from GitHub Releases
  # No source code, no tests, just compiled package
```

## Migration Path

### **Phase 1: Extract config-manager (Proof of Concept)**

```bash
# 1. Make config-manager a standalone repo
cd /opt/openproject/external/config-manager
gh repo create JustinCBates/config-manager --public --source=.

# 2. Set up branches
git checkout -b build
git checkout -b main
git push origin develop build main

# 3. Add build workflow
# (copy from template)

# 4. Create first release
git checkout build
# Trigger build → creates v3.0.0 release with wheel

# 5. Update orchestrator to use package
cd /opt/openproject
# Edit pyproject.toml:
dependencies = [
    "openproject-config-manager @ https://github.com/JustinCBates/config-manager/releases/download/v3.0.0/openproject_config_manager-3.0.0-py3-none-any.whl"
]

# 6. Remove submodule
git rm external/config-manager
git submodule deinit external/config-manager

# 7. Test
pip install -e .
# Should download and install config-manager automatically

# 8. Remove sys.path hacks
# Delete _setup_development_imports() from coordinators
```

### **Phase 2: Repeat for all submodules**

Repeat the above for:
- deploy-manager
- prober
- control-flow
- dependency-manager
- tui-form-designer

### **Phase 3: Clean up orchestrator**

```python
# Before:
class ConfigCoordinator:
    def __init__(self):
        self._setup_development_imports()  # Complex sys.path manipulation
        
# After:
class ConfigCoordinator:
    def __init__(self):
        from openproject_config_manager import ConfigurationManager
        # Just works! pip installed it.
```

## Which Package Index to Use?

### **Option 1: GitHub Releases (Recommended for You)**

**Pros:**
- ✅ Free for private repos
- ✅ Integrated with GitHub
- ✅ No external services needed
- ✅ Works with GitHub Actions

**Cons:**
- ❌ Slightly longer URLs in dependencies
- ❌ Not searchable like PyPI

**Best for:** Private/internal packages

### **Option 2: PyPI (Public Package Index)**

**Pros:**
- ✅ Standard Python package index
- ✅ Easy installation: `pip install openproject-orchestrator`
- ✅ Discoverable and searchable
- ✅ Free for open source

**Cons:**
- ❌ Only for public packages
- ❌ Package names must be globally unique

**Best for:** Open source projects

### **Option 3: Private PyPI Server**

**Pros:**
- ✅ Full PyPI-like experience
- ✅ Private packages
- ✅ Can mirror public PyPI

**Cons:**
- ❌ Need to self-host
- ❌ Extra infrastructure

**Best for:** Large organizations with many internal packages

## Recommendation

**Use GitHub Releases** for your setup because:

1. You already use GitHub
2. Repos might be private
3. Simple to set up
4. Works perfectly with your build branch strategy
5. No additional infrastructure

## Summary

Linux package managers (apt, yum) and pip work the same way:

1. **Metadata** describes dependencies
2. **Dependency resolver** builds install order
3. **Packages downloaded** from central repository
4. **Installed** in dependency order

Your repos should mirror this:

- Each component = separate package with own repo
- Build branch = creates wheel & GitHub release
- Main orchestrator = declares dependencies in pyproject.toml
- pip = automatically downloads and installs everything

**No more git submodules!** 🎉
