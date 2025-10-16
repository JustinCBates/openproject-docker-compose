# Development Workspace Setup with Multiple Repos

## Yes! You Can Have Local Development Branches

### Recommended Development Workspace Structure

```
~/workspace/openproject/
├── openproject-orchestrator/     ← Main repo (develop branch)
│   ├── .git/
│   ├── src/
│   ├── tests/
│   └── pyproject.toml
│
├── config-manager/               ← Component repo (develop branch)
│   ├── .git/
│   ├── src/
│   ├── tests/
│   └── pyproject.toml
│
├── deploy-manager/               ← Component repo (develop branch)
│   ├── .git/
│   ├── src/
│   ├── tests/
│   └── pyproject.toml
│
└── ... (other component repos)
```

### Two Modes of Development

#### **Mode 1: Using Released Packages (Default)**

This is for users or when you're not actively developing a component:

```bash
cd ~/workspace/openproject-orchestrator/

# pyproject.toml points to releases:
[project]
dependencies = [
    "openproject-config-manager==3.0.0",  # From GitHub release
    "openproject-deploy-manager==2.0.0"   # From GitHub release
]

# Install everything:
pip install -e .

# This downloads wheels from GitHub releases
# Orchestrator uses installed packages from site-packages/
```

#### **Mode 2: Local Development with Editable Installs (Development)**

This is when you're actively developing multiple components:

```bash
# Clone all repos you're working on
cd ~/workspace/
git clone https://github.com/JustinCBates/openproject-orchestrator.git
git clone https://github.com/JustinCBates/config-manager.git
git clone https://github.com/JustinCBates/deploy-manager.git

# Checkout develop branches
cd openproject-orchestrator && git checkout develop && cd ..
cd config-manager && git checkout develop && cd ..
cd deploy-manager && git checkout develop && cd ..

# Install components in editable mode (development)
pip install -e ./config-manager/
pip install -e ./deploy-manager/

# Install main orchestrator in editable mode
pip install -e ./openproject-orchestrator/

# Now changes to any repo are immediately reflected!
```

### Development Workflow Options

#### **Option A: pip with Editable Installs (Recommended)**

```bash
# Install all repos in development mode
pip install -e ~/workspace/config-manager/
pip install -e ~/workspace/deploy-manager/
pip install -e ~/workspace/orchestrator/

# Now you can edit any file and changes are live!
cd ~/workspace/config-manager/
# Edit src/openproject_config_manager/core/config.py
# Changes are immediately available when you import in orchestrator

cd ~/workspace/orchestrator/
python -m openproject_orchestrator deploy
# Uses your local edited version of config-manager!
```

**Benefits:**
- ✅ Edit any file, changes are immediate
- ✅ No build/install cycle needed
- ✅ Proper imports (no sys.path hacks)
- ✅ Each repo has own git history
- ✅ Can commit independently

#### **Option B: Environment Variable Override**

You can add development mode detection to pyproject.toml:

```toml
# pyproject.toml
[project]
dependencies = [
    # Default to releases
    "openproject-config-manager==3.0.0",
]

[project.optional-dependencies]
dev = [
    # For development, use git dependencies or local paths
    # These override the release versions
]
```

Then create a development install script:

```bash
#!/bin/bash
# scripts/dev_install.sh

# Check if local repos exist
if [ -d "../config-manager" ]; then
    echo "Installing config-manager from local repo (editable)..."
    pip install -e ../config-manager/
else
    echo "Installing config-manager from release..."
    pip install openproject-config-manager==3.0.0
fi

if [ -d "../deploy-manager" ]; then
    echo "Installing deploy-manager from local repo (editable)..."
    pip install -e ../deploy-manager/
else
    echo "Installing deploy-manager from release..."
    pip install openproject-deploy-manager==2.0.0
fi

# Install orchestrator itself
pip install -e .
```

#### **Option C: Use requirements-dev.txt**

```bash
# requirements-dev.txt
-e ../config-manager/
-e ../deploy-manager/
-e ../prober/
-e .  # orchestrator itself

# Install all in editable mode:
pip install -r requirements-dev.txt
```

### VSCode Multi-Root Workspace

You can use VSCode's multi-root workspace feature:

```json
// openproject.code-workspace
{
    "folders": [
        {
            "path": "openproject-orchestrator",
            "name": "Orchestrator (Main)"
        },
        {
            "path": "config-manager",
            "name": "Config Manager"
        },
        {
            "path": "deploy-manager",
            "name": "Deploy Manager"
        },
        {
            "path": "prober",
            "name": "Prober"
        }
    ],
    "settings": {
        "python.defaultInterpreterPath": "${workspaceFolder:Orchestrator (Main)}/venv/bin/python"
    }
}
```

**Benefits:**
- See all repos in one window
- Git works independently for each
- Shared Python environment
- Easy to navigate between components

### Git Workflow with Multiple Repos

```bash
# Working on config-manager feature
cd ~/workspace/config-manager/
git checkout develop
git checkout -b feature/new-validator
# ... make changes ...
git commit -m "feat: add new validator"
git push origin feature/new-validator
gh pr create --base develop

# Test it in orchestrator immediately
cd ~/workspace/orchestrator/
python -m openproject_orchestrator deploy
# Uses your local changes since it's installed with -e!

# Once merged to develop, create release
cd ~/workspace/config-manager/
git checkout develop
git pull
# Update version to 3.1.0
git commit -m "chore: bump version to 3.1.0"
git push
gh pr create --base build  # Triggers release

# Update orchestrator to use new version
cd ~/workspace/orchestrator/
# Edit pyproject.toml: config-manager==3.0.0 → config-manager==3.1.0
git commit -m "deps: update config-manager to 3.1.0"
```

### Testing Different Versions

```bash
# Test with released version
pip install openproject-config-manager==3.0.0
python -m openproject_orchestrator deploy

# Test with unreleased develop branch
pip uninstall openproject-config-manager
pip install -e ~/workspace/config-manager/
python -m openproject_orchestrator deploy

# Test with specific feature branch
cd ~/workspace/config-manager/
git checkout feature/experimental
cd ~/workspace/orchestrator/
python -m openproject_orchestrator deploy
# Uses experimental feature!
```

### Environment Management

You can use different virtual environments for different scenarios:

```bash
# Production-like environment (releases only)
python -m venv venv-prod
source venv-prod/bin/activate
pip install openproject-orchestrator
# Installs all from releases

# Development environment (local editable)
python -m venv venv-dev
source venv-dev/bin/activate
pip install -e ~/workspace/config-manager/
pip install -e ~/workspace/deploy-manager/
pip install -e ~/workspace/orchestrator/
# All editable, live changes

# Testing specific versions
python -m venv venv-test
source venv-test/bin/activate
pip install openproject-config-manager==2.9.0  # Test with older version
pip install -e ~/workspace/orchestrator/
```

## Summary: Development Workspace

**Yes, you can absolutely have local development branches!**

**Recommended Setup:**
1. Clone all repos you're developing into one workspace directory
2. Checkout develop branches
3. Install with `pip install -e ./repo-name/` (editable mode)
4. Edit any file, changes are immediate
5. Each repo maintains its own git history
6. When ready, create PRs in individual repos
7. Releases happen independently

**Benefits:**
- ✅ Standard Python development workflow
- ✅ No special tooling needed
- ✅ Each repo independent but can work together
- ✅ Test changes before releasing
- ✅ Proper imports (no sys.path manipulation)

The key difference from submodules:
- **Submodules**: Parent repo controls exact commit of child
- **Packages**: Each repo is independent, you choose which version/branch to use
