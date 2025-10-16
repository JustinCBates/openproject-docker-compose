# GitHub as a Python Package Repository - Complete Guide

## Question: Can GitHub handle pip calls to the repo?

**Answer: YES! GitHub has multiple ways to serve Python packages to pip.**

## Option 1: Install from GitHub Releases (Recommended) ✅

GitHub Releases can host wheel files that pip can download directly.

### How It Works

```bash
# GitHub automatically creates a permanent URL for release artifacts:
https://github.com/OWNER/REPO/releases/download/TAG/FILENAME

# Example:
https://github.com/JustinCBates/config-manager/releases/download/v3.0.0/openproject_config_manager-3.0.0-py3-none-any.whl
```

### In pyproject.toml

```toml
[project]
dependencies = [
    "openproject-config-manager @ https://github.com/JustinCBates/config-manager/releases/download/v3.0.0/openproject_config_manager-3.0.0-py3-none-any.whl"
]
```

### Installation

```bash
# pip automatically downloads from GitHub
pip install openproject-orchestrator

# pip does:
# 1. Reads pyproject.toml
# 2. Sees GitHub URL for dependency
# 3. Downloads wheel from GitHub releases
# 4. Installs it
```

### Creating a Release with Wheel

```yaml
# .github/workflows/release.yml
name: Release

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
      
      - name: Get version
        id: version
        run: |
          VERSION=$(grep -Po '(?<=^version = ")[^"]*' pyproject.toml)
          echo "version=$VERSION" >> $GITHUB_OUTPUT
      
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: v${{ steps.version.outputs.version }}
          name: Config Manager v${{ steps.version.outputs.version }}
          files: dist/*  # Uploads all wheels and tarballs
          body: |
            ## Installation
            ```bash
            pip install https://github.com/${{ github.repository }}/releases/download/v${{ steps.version.outputs.version }}/openproject_config_manager-${{ steps.version.outputs.version }}-py3-none-any.whl
            ```
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Result:** GitHub creates a release with downloadable wheel that pip can install.

### Advantages
- ✅ **Free**: No cost for public or private repos
- ✅ **No authentication** for public repos
- ✅ **Permanent URLs**: Release artifacts never change
- ✅ **Versioned**: Each release has its own tag
- ✅ **Works with pip**: Standard pip URL format
- ✅ **Fast CDN**: GitHub uses global CDN for releases

### Disadvantages
- ❌ Longer URLs in dependencies
- ❌ Not searchable like PyPI
- ❌ No automatic version resolution (must specify exact URL)

## Option 2: Install Directly from Git (Built-in) ✅

GitHub natively supports pip installing directly from git repositories.

### Install from Git Tag

```bash
# Specific version (tag)
pip install git+https://github.com/JustinCBates/config-manager.git@v3.0.0

# Or in pyproject.toml:
dependencies = [
    "openproject-config-manager @ git+https://github.com/JustinCBates/config-manager.git@v3.0.0"
]
```

### Install from Branch

```bash
# Specific branch
pip install git+https://github.com/JustinCBates/config-manager.git@develop

# Or in pyproject.toml:
dependencies = [
    "openproject-config-manager @ git+https://github.com/JustinCBates/config-manager.git@develop"
]
```

### Install from Commit

```bash
# Specific commit SHA
pip install git+https://github.com/JustinCBates/config-manager.git@abc123def456
```

### How It Works

```bash
# When you run:
pip install git+https://github.com/JustinCBates/config-manager.git@v3.0.0

# pip does:
# 1. Clones the git repository
# 2. Checks out the specified tag/branch/commit
# 3. Looks for setup.py or pyproject.toml
# 4. Builds the package (runs python -m build)
# 5. Installs the built package
```

### Advantages
- ✅ **Simple syntax**: Just add `git+` before URL
- ✅ **No release needed**: Install from any branch/commit/tag
- ✅ **Good for development**: Can install from develop branch
- ✅ **Works with private repos**: Use SSH or token auth

### Disadvantages
- ❌ **Slower**: Must clone and build on every install
- ❌ **Requires git**: User must have git installed
- ❌ **Not cached**: pip can't cache git installs as efficiently

## Option 3: GitHub Packages (PyPI Alternative) ✅

GitHub has a built-in package registry that works like PyPI.

### Setup GitHub Packages

```yaml
# .github/workflows/publish.yml
name: Publish to GitHub Packages

on:
  release:
    types: [created]

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      
      - name: Build package
        run: |
          pip install build
          python -m build
      
      - name: Publish to GitHub Packages
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          pip install twine
          twine upload --repository-url https://upload.github.com/JustinCBates/config-manager/ dist/*
```

### Install from GitHub Packages

```bash
# Configure pip to use GitHub Packages
pip install --index-url https://pypi.pkg.github.com/JustinCBates/ openproject-config-manager

# Or add to pip.conf:
[global]
extra-index-url = https://pypi.pkg.github.com/JustinCBates/
```

### In pyproject.toml

```toml
# Unfortunately, pyproject.toml doesn't support specifying index per package
# You must configure pip globally or use a different method
```

### Advantages
- ✅ **PyPI-like interface**: Works like PyPI
- ✅ **Package registry**: Proper version management
- ✅ **Private packages**: Good for private repos

### Disadvantages
- ❌ **Authentication required**: Even for public packages
- ❌ **Complex setup**: More configuration needed
- ❌ **Not widely used**: Less common than PyPI or releases

## Option 4: Use PyPI (Public Packages) ✅

For open-source projects, publish to the real PyPI.

### Publish to PyPI

```yaml
# .github/workflows/pypi-publish.yml
name: Publish to PyPI

on:
  release:
    types: [created]

jobs:
  publish:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Build package
        run: |
          pip install build
          python -m build
      
      - name: Publish to PyPI
        uses: pypa/gh-action-pypi-publish@release/v1
        with:
          password: ${{ secrets.PYPI_API_TOKEN }}
```

### Install from PyPI

```bash
# Simple!
pip install openproject-config-manager

# In pyproject.toml:
dependencies = [
    "openproject-config-manager==3.0.0"
]
```

### Advantages
- ✅ **Standard**: The official Python package index
- ✅ **Simple installation**: Just `pip install package-name`
- ✅ **Discoverable**: Searchable on pypi.org
- ✅ **Free**: For open-source projects
- ✅ **Fast CDN**: Global mirrors

### Disadvantages
- ❌ **Public only**: Can't host private packages
- ❌ **Name must be unique**: Globally across all PyPI

## Comparison Table

| Method | Private Repos | Auth Required | Speed | Caching | Ease of Use |
|--------|---------------|---------------|-------|---------|-------------|
| **GitHub Releases** | ✅ Yes | ❌ No (public) | ⚡ Fast | ✅ Yes | ⭐⭐⭐⭐ |
| **Git Install** | ✅ Yes | ⚠️ For private | 🐌 Slow | ⚠️ Limited | ⭐⭐⭐ |
| **GitHub Packages** | ✅ Yes | ✅ Always | ⚡ Fast | ✅ Yes | ⭐⭐ |
| **PyPI** | ❌ No | ❌ No | ⚡ Fast | ✅ Yes | ⭐⭐⭐⭐⭐ |

## Recommended Approach for Your Setup

### For Private Development

```toml
# Use GitHub Releases (build branch creates these)
[project]
dependencies = [
    "openproject-config-manager @ https://github.com/JustinCBates/config-manager/releases/download/v3.0.0/openproject_config_manager-3.0.0-py3-none-any.whl",
    "openproject-deploy-manager @ https://github.com/JustinCBates/deploy-manager/releases/download/v2.0.0/openproject_deploy_manager-2.0.0-py3-none-any.whl"
]
```

### For Public Open Source

```toml
# Publish to PyPI, use standard package names
[project]
dependencies = [
    "openproject-config-manager==3.0.0",
    "openproject-deploy-manager==2.0.0"
]
```

### For Local Development

```bash
# Use editable installs
pip install -e ~/workspace/config-manager/
pip install -e ~/workspace/deploy-manager/
pip install -e ~/workspace/orchestrator/
```

## Authentication for Private Repos

### Option 1: SSH Keys (Recommended for git installs)

```bash
# Use SSH URL for private repos
pip install git+ssh://git@github.com/JustinCBates/config-manager.git@v3.0.0

# In pyproject.toml:
dependencies = [
    "openproject-config-manager @ git+ssh://git@github.com/JustinCBates/config-manager.git@v3.0.0"
]
```

**Setup:**
```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Add to GitHub account
cat ~/.ssh/id_ed25519.pub
# Copy to GitHub Settings → SSH Keys
```

### Option 2: Personal Access Token (For HTTPS)

```bash
# Use token in URL
pip install git+https://USERNAME:TOKEN@github.com/JustinCBates/config-manager.git@v3.0.0

# Better: Configure git to use token
git config --global credential.helper store
git config --global user.name "Your Name"
git config --global user.email "your_email@example.com"

# Then git will prompt for token once and remember it
```

### Option 3: GitHub Releases (No Auth for Downloads)

```bash
# GitHub releases are downloadable without auth for private repos
# if you have a direct URL (which pip uses)
pip install https://github.com/JustinCBates/config-manager/releases/download/v3.0.0/openproject_config_manager-3.0.0-py3-none-any.whl

# This works even for private repos!
```

**Note:** Anyone with the URL can download, but the URL is only known to you.

## Complete Example: Your Workflow

### 1. Build Branch Creates Release

```yaml
# config-manager/.github/workflows/release.yml
on:
  push:
    branches: [build]

jobs:
  release:
    steps:
      - name: Build wheel
        run: python -m build
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: v3.0.0
          files: dist/*.whl
```

**Result:** 
- GitHub creates release at: `https://github.com/JustinCBates/config-manager/releases/tag/v3.0.0`
- Wheel URL: `https://github.com/JustinCBates/config-manager/releases/download/v3.0.0/openproject_config_manager-3.0.0-py3-none-any.whl`

### 2. Orchestrator Uses Release

```toml
# orchestrator/pyproject.toml
[project]
dependencies = [
    "openproject-config-manager @ https://github.com/JustinCBates/config-manager/releases/download/v3.0.0/openproject_config_manager-3.0.0-py3-none-any.whl"
]
```

### 3. User Installs

```bash
pip install openproject-orchestrator

# pip automatically:
# 1. Downloads orchestrator package
# 2. Reads dependencies
# 3. Downloads config-manager wheel from GitHub
# 4. Installs both
```

### 4. Development Mode

```bash
# Developer clones both repos
git clone https://github.com/JustinCBates/orchestrator.git
git clone https://github.com/JustinCBates/config-manager.git

# Install in editable mode
pip install -e ./config-manager/
pip install -e ./orchestrator/

# Now changes to config-manager are immediately available!
```

## Summary

**Can GitHub handle pip calls?**

**YES!** GitHub supports pip in multiple ways:

1. **GitHub Releases** (Recommended)
   - Build branch creates release with wheel
   - pip downloads from release URL
   - Works for public and private repos
   - No authentication needed for direct URLs

2. **Git Install** (Development)
   - `pip install git+https://github.com/...`
   - Works for any branch/tag/commit
   - Good for testing unreleased code

3. **GitHub Packages** (Enterprise)
   - Works like PyPI
   - Requires authentication
   - Good for large organizations

4. **PyPI** (Open Source)
   - Standard Python repository
   - Easiest for users
   - Only for public packages

**Your build branch strategy works perfectly with GitHub Releases!**

The workflow:
```
develop → build (creates wheel + GitHub release) → main (production config)
                          ↓
          pip installs from GitHub release URL
```

This is **standard practice** and exactly how many Python projects work!
