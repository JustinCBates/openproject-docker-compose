# Quick Reference: Development with Multiple Repos

## TL;DR - Answers to Your Questions

### Q1: Can workspace still have development branches for each repo?

**YES!** Here's the simple setup:

```bash
# Clone all repos
cd ~/workspace/
git clone https://github.com/JustinCBates/orchestrator.git
git clone https://github.com/JustinCBates/config-manager.git
git clone https://github.com/JustinCBates/deploy-manager.git

# Checkout develop branches
cd orchestrator && git checkout develop && cd ..
cd config-manager && git checkout develop && cd ..
cd deploy-manager && git checkout develop && cd ..

# Install all in editable mode (changes are live!)
pip install -e ./config-manager/
pip install -e ./deploy-manager/
pip install -e ./orchestrator/

# Now edit any file and it works immediately! ✨
```

### Q2: Can GitHub handle pip calls?

**YES!** Multiple ways:

```bash
# Method 1: From GitHub Releases (Recommended)
pip install https://github.com/OWNER/REPO/releases/download/v1.0.0/package-1.0.0-py3-none-any.whl

# Method 2: From Git tag/branch
pip install git+https://github.com/OWNER/REPO.git@v1.0.0

# Method 3: From GitHub Packages (like PyPI)
pip install --index-url https://pypi.pkg.github.com/OWNER/ package

# Method 4: From PyPI (if published)
pip install package
```

## Common Workflows

### Workflow 1: Develop Multiple Components Simultaneously

```bash
# Day 1: Setup
cd ~/workspace/
git clone https://github.com/JustinCBates/orchestrator.git
git clone https://github.com/JustinCBates/config-manager.git

pip install -e ./config-manager/
pip install -e ./orchestrator/

# Day 2: Work on config-manager feature
cd config-manager/
git checkout -b feature/new-validator
# Edit files...
git commit -m "feat: add validator"

# Test immediately in orchestrator
cd ../orchestrator/
python -m openproject_orchestrator deploy
# Uses your local changes! No rebuild needed!

# Day 3: Merge and release
cd ../config-manager/
git push origin feature/new-validator
gh pr create --base develop
gh pr merge
# Bump version to 3.1.0
gh pr create --base build  # Triggers release

# Day 4: Update orchestrator to use new release
cd ../orchestrator/
# Edit pyproject.toml: config-manager==3.0.0 → 3.1.0
git commit -m "deps: update config-manager"
```

### Workflow 2: Use Released Versions (Production-like)

```bash
# Install from releases (like end users)
pip install openproject-orchestrator

# Orchestrator's pyproject.toml has:
dependencies = [
    "openproject-config-manager @ https://github.com/.../releases/.../v3.0.0/...whl"
]

# pip automatically downloads everything from GitHub releases
```

### Workflow 3: Test Unreleased Changes

```bash
# Install specific branch from git
pip install git+https://github.com/JustinCBates/config-manager.git@feature/experimental

# Or clone and install editable
git clone https://github.com/JustinCBates/config-manager.git
cd config-manager
git checkout feature/experimental
cd ..
pip install -e ./config-manager/
```

## File Structure Comparison

### Current (Submodules)
```
openproject-orchestrator/
├── .git/
├── external/
│   ├── config-manager/    ← Submodule (locked to specific commit)
│   ├── deploy-manager/    ← Submodule
│   └── ...
└── src/
    └── orchestrator/
        └── __init__.py
            # import sys; sys.path.insert(...)  😞
```

**Problems:**
- Must run `git submodule update`
- sys.path hacks required
- Can't version components independently
- All tightly coupled

### Recommended (Packages)
```
~/workspace/
├── orchestrator/           ← Independent repo
│   ├── .git/
│   └── pyproject.toml
│       dependencies = ["config-manager==3.0.0"]
│
├── config-manager/         ← Independent repo
│   ├── .git/
│   └── pyproject.toml
│
└── deploy-manager/         ← Independent repo
    ├── .git/
    └── pyproject.toml
```

**Benefits:**
- Standard pip install
- No sys.path hacks
- Independent versioning
- pip handles everything

## pyproject.toml Examples

### For End Users (Use Releases)

```toml
# orchestrator/pyproject.toml
[project]
name = "openproject-orchestrator"
version = "2.0.0"

dependencies = [
    # Install from GitHub releases (recommended)
    "openproject-config-manager @ https://github.com/JustinCBates/config-manager/releases/download/v3.0.0/openproject_config_manager-3.0.0-py3-none-any.whl",
    
    # Or from PyPI (if published)
    # "openproject-config-manager==3.0.0",
    
    # Or from git tag
    # "openproject-config-manager @ git+https://github.com/JustinCBates/config-manager.git@v3.0.0",
]
```

### For Developers (Use Editable Installs)

```bash
# Don't modify pyproject.toml
# Just install components in editable mode:

pip install -e ~/workspace/config-manager/
pip install -e ~/workspace/deploy-manager/
pip install -e ~/workspace/orchestrator/

# This overrides the dependencies in pyproject.toml
# with your local editable versions
```

## Development Scenarios

### Scenario 1: Fix Bug in config-manager

```bash
# 1. Clone if you don't have it
git clone https://github.com/JustinCBates/config-manager.git

# 2. Install editable
pip install -e ./config-manager/

# 3. Create feature branch
cd config-manager
git checkout -b fix/validation-error

# 4. Fix the bug
# Edit src/...

# 5. Test in orchestrator
cd ../orchestrator
python -m openproject_orchestrator deploy
# Uses your fixed version immediately!

# 6. Create PR
cd ../config-manager
git commit -m "fix: validation error"
git push origin fix/validation-error
gh pr create --base develop
```

### Scenario 2: Add Feature Across Multiple Repos

```bash
# Need to add feature that touches both config-manager and orchestrator

# 1. Create feature branches
cd config-manager
git checkout -b feature/advanced-config
cd ../orchestrator
git checkout -b feature/advanced-config

# 2. Install both editable
pip install -e ../config-manager/
pip install -e .

# 3. Make changes to both repos
# Edit config-manager/src/...
# Edit orchestrator/src/...

# 4. Test together (changes are live!)
python -m openproject_orchestrator deploy

# 5. Create PRs for both
cd ../config-manager
git commit -m "feat: add advanced config support"
git push origin feature/advanced-config
gh pr create --base develop

cd ../orchestrator
git commit -m "feat: use advanced config"
git push origin feature/advanced-config
gh pr create --base develop

# 6. Merge config-manager first, create release
# 7. Update orchestrator to use new release version
# 8. Merge orchestrator
```

### Scenario 3: Use Specific Version

```bash
# Want to test orchestrator with older config-manager

# Option A: Install specific release
pip install https://github.com/JustinCBates/config-manager/releases/download/v2.9.0/openproject_config_manager-2.9.0-py3-none-any.whl

# Option B: Install from git tag
pip install git+https://github.com/JustinCBates/config-manager.git@v2.9.0

# Option C: Clone and checkout tag
git clone https://github.com/JustinCBates/config-manager.git
cd config-manager
git checkout v2.9.0
cd ..
pip install -e ./config-manager/
```

## VSCode Setup

### Multi-Root Workspace (Recommended)

File: `openproject.code-workspace`
```json
{
    "folders": [
        {"path": "orchestrator", "name": "🎯 Orchestrator (Main)"},
        {"path": "config-manager", "name": "⚙️ Config Manager"},
        {"path": "deploy-manager", "name": "🚀 Deploy Manager"},
        {"path": "prober", "name": "🔍 Prober"},
        {"path": "control-flow", "name": "🌊 Control Flow"},
        {"path": "dependency-manager", "name": "📦 Dependency Manager"},
        {"path": "tui-form-designer", "name": "🖥️ TUI Form Designer"}
    ],
    "settings": {
        "python.defaultInterpreterPath": "${workspaceFolder:🎯 Orchestrator (Main)}/venv/bin/python",
        "python.testing.pytestEnabled": true,
        "python.linting.enabled": true,
        "python.formatting.provider": "black"
    }
}
```

**Open workspace:**
```bash
code openproject.code-workspace
```

**Benefits:**
- All repos in one window
- Shared Python interpreter
- Independent git for each folder
- Easy navigation between repos

## Git Commands Cheat Sheet

### Setup All Repos

```bash
# Clone all repos
cd ~/workspace/
for repo in orchestrator config-manager deploy-manager prober control-flow dependency-manager tui-form-designer; do
    git clone https://github.com/JustinCBates/$repo.git
done

# Checkout develop on all
for repo in */; do
    cd "$repo"
    git checkout develop
    cd ..
done

# Install all editable
pip install -e ./config-manager/
pip install -e ./deploy-manager/
pip install -e ./prober/
pip install -e ./control-flow/
pip install -e ./dependency-manager/
pip install -e ./tui-form-designer/
pip install -e ./orchestrator/
```

### Update All Repos

```bash
# Pull latest from all repos
for repo in */; do
    cd "$repo"
    git pull
    cd ..
done
```

### Status of All Repos

```bash
# Check git status of all repos
for repo in */; do
    echo "=== $repo ==="
    cd "$repo"
    git status -s
    cd ..
done
```

## Common Issues & Solutions

### Issue 1: "Module not found" after editing

**Problem:** You edited a file but import still fails.

**Solution:**
```bash
# Make sure you installed with -e (editable)
pip install -e ./config-manager/

# NOT just:
pip install ./config-manager/  # ❌ This copies files, changes won't reflect
```

### Issue 2: Can't push to submodule

**Problem:** Submodule is in "detached HEAD" state.

**Solution:** With packages, you don't have this problem! Each repo is independent.
```bash
cd config-manager/  # No longer a submodule
git checkout develop
git pull
# Just works! ✅
```

### Issue 3: Dependency version conflicts

**Problem:** Orchestrator expects v3.0.0 but you have v3.1.0 installed.

**Solution:**
```bash
# For development, editable install overrides version
pip install -e ./config-manager/  # Uses whatever is in the repo

# For production, install exact version
pip install https://github.com/.../v3.0.0/...whl
```

## Summary

### ✅ Both Questions: YES!

1. **Can workspace have dev branches?** → YES! Use `pip install -e ./repo/`
2. **Can GitHub handle pip?** → YES! Via releases, git URLs, or packages

### Key Takeaways

- Each component is an independent repo
- Use `pip install -e ./repo/` for development (live changes)
- Use GitHub releases for distribution (build branch creates these)
- No git submodules, no sys.path hacks
- Standard Python development workflow

### Your Build Branch Strategy Works Perfectly!

```
develop  → Feature development (local editable installs)
   ↓
build    → Creates wheel & GitHub release (pip installs from here)
   ↓
main     → Production config (users install from releases)
```

This is **exactly** how professional Python projects work! 🎉
