# Multi-Repo Package Architecture - Visual Summary

## Current Architecture (Submodules) ❌

```
┌─────────────────────────────────────────────────────────────────┐
│ openproject-orchestrator (main repo)                            │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ external/                                                   │ │
│  │  ├── config-manager/      ← git submodule                  │ │
│  │  ├── deploy-manager/      ← git submodule                  │ │
│  │  ├── prober/              ← git submodule                  │ │
│  │  ├── control-flow/        ← git submodule                  │ │
│  │  ├── dependency-manager/  ← git submodule                  │ │
│  │  └── tui-form-designer/   ← git submodule                  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  Problems:                                                       │
│  - Must sync all submodules manually                            │
│  - sys.path manipulation needed                                 │
│  - All components tightly coupled                               │
│  - No independent versioning                                    │
│  - Cloning is slow (7 repos)                                    │
└─────────────────────────────────────────────────────────────────┘
```

## Recommended Architecture (Packages) ✅

```
┌─────────────────────────────────────────────────────────────────┐
│ GitHub Repos (6 independent packages)                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  config-manager repo         → v3.0.0                           │
│    develop → build → main                                       │
│    Publishes: openproject_config_manager-3.0.0-py3-none-any.whl│
│                                                                  │
│  deploy-manager repo         → v2.0.0                           │
│    develop → build → main                                       │
│    Publishes: openproject_deploy_manager-2.0.0-py3-none-any.whl│
│                                                                  │
│  prober repo                 → v1.0.0                           │
│  control-flow repo           → v1.5.0                           │
│  dependency-manager repo     → v1.2.0                           │
│  tui-form-designer repo      → v2.1.0                           │
│                                                                  │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     │ pip install (from GitHub Releases)
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ openproject-orchestrator repo (main application)                │
│                                                                  │
│  pyproject.toml:                                                │
│    dependencies = [                                             │
│      "openproject-config-manager==3.0.0",                       │
│      "openproject-deploy-manager==2.0.0",                       │
│      "prober==1.0.0",                                           │
│      ...                                                        │
│    ]                                                            │
│                                                                  │
│  Benefits:                                                       │
│  ✓ pip handles all dependencies automatically                   │
│  ✓ No sys.path manipulation needed                              │
│  ✓ Each component versions independently                        │
│  ✓ Standard Python packaging                                    │
│  ✓ Fast cloning (1 repo)                                        │
└─────────────────────────────────────────────────────────────────┘
```

## Branch Workflow (Same for ALL Repos)

```
┌──────────────────────────────────────────────────────────────┐
│ DEVELOP BRANCH (default)                                     │
│                                                              │
│ Purpose: Active development                                  │
│ Contains: All source code, tests, docs, dev dependencies    │
│                                                              │
│ Files:                                                       │
│  src/                    ← Source code                       │
│  tests/                  ← Test suite                        │
│  docs/                   ← Documentation                     │
│  scripts/                ← Build scripts                     │
│  pyproject.toml          ← Full dependencies (dev + prod)   │
│  .github/workflows/      ← CI/CD                             │
│  README.md               ← Development guide                 │
└──────────────────────────────────────────────────────────────┘
                          │
                          │ PR (after tests pass)
                          ↓
┌──────────────────────────────────────────────────────────────┐
│ BUILD BRANCH                                                 │
│                                                              │
│ Purpose: Package creation and release automation            │
│ Trigger: PR from develop                                     │
│                                                              │
│ GitHub Actions Workflow:                                     │
│  1. Run full test suite                                      │
│  2. Build wheel: package-3.0.0-py3-none-any.whl             │
│  3. Create GitHub Release (v3.0.0)                          │
│  4. Attach wheel to release                                 │
│  5. Optional: Publish to PyPI                               │
│  6. Clean up dev files from branch                          │
│                                                              │
│ Remaining Files:                                             │
│  pyproject.toml          ← Production deps only             │
│  README.md               ← Installation instructions         │
│  LICENSE                                                     │
│  .github/workflows/      ← Build automation                 │
└──────────────────────────────────────────────────────────────┘
                          │
                          │ Creates Release
                          ↓
┌──────────────────────────────────────────────────────────────┐
│ GITHUB RELEASE v3.0.0                                        │
│                                                              │
│ Artifacts:                                                   │
│  openproject_config_manager-3.0.0-py3-none-any.whl          │
│  openproject_config_manager-3.0.0.tar.gz                    │
│                                                              │
│ Users install from here:                                     │
│  pip install <wheel-url>                                     │
└──────────────────────────────────────────────────────────────┘
                          │
                          │ Manual PR (validated release)
                          ↓
┌──────────────────────────────────────────────────────────────┐
│ MAIN BRANCH (production reference)                          │
│                                                              │
│ Purpose: Production deployment configuration                │
│                                                              │
│ Files:                                                       │
│  README.md               ← Production deployment guide       │
│  docker-compose.yml      ← If applicable                    │
│  production_config.yaml  ← Production defaults              │
│  .github/workflows/      ← Deployment automation            │
│  LICENSE                                                     │
│                                                              │
│ What's NOT here:                                             │
│  ✗ Source code (users install from releases)                │
│  ✗ Tests                                                     │
│  ✗ Build scripts                                             │
└──────────────────────────────────────────────────────────────┘
```

## Comparison: Linux Package Management

### How apt Works (Debian/Ubuntu)

```
User runs: apt install python3-requests
             ↓
┌─────────────────────────────────────────────────────┐
│ 1. Query Repository                                 │
│    URL: http://archive.ubuntu.com/ubuntu/           │
│    Package: python3-requests                        │
└─────────────────────────────────────────────────────┘
             ↓
┌─────────────────────────────────────────────────────┐
│ 2. Download Metadata (.deb control file)            │
│    Package: python3-requests                        │
│    Version: 2.31.0-1                                │
│    Depends: python3-urllib3, python3-certifi        │
└─────────────────────────────────────────────────────┘
             ↓
┌─────────────────────────────────────────────────────┐
│ 3. Resolve Dependencies                             │
│    requests → urllib3, certifi, charset-normalizer  │
└─────────────────────────────────────────────────────┘
             ↓
┌─────────────────────────────────────────────────────┐
│ 4. Download .deb Files                              │
│    python3-requests_2.31.0-1_all.deb               │
│    python3-urllib3_2.0.0-1_all.deb                 │
│    python3-certifi_2023.7.22-1_all.deb             │
└─────────────────────────────────────────────────────┘
             ↓
┌─────────────────────────────────────────────────────┐
│ 5. Install in Order                                 │
│    /usr/lib/python3/dist-packages/certifi/          │
│    /usr/lib/python3/dist-packages/urllib3/          │
│    /usr/lib/python3/dist-packages/requests/         │
└─────────────────────────────────────────────────────┘
```

### How pip Works (Python)

```
User runs: pip install openproject-orchestrator
             ↓
┌─────────────────────────────────────────────────────┐
│ 1. Query Index                                      │
│    PyPI: https://pypi.org/simple/                   │
│    or GitHub: releases/download/                    │
└─────────────────────────────────────────────────────┘
             ↓
┌─────────────────────────────────────────────────────┐
│ 2. Download Metadata (METADATA from wheel)          │
│    Name: openproject-orchestrator                   │
│    Version: 2.0.0                                   │
│    Requires-Dist: openproject-config-manager==3.0.0 │
│    Requires-Dist: openproject-deploy-manager==2.0.0 │
└─────────────────────────────────────────────────────┘
             ↓
┌─────────────────────────────────────────────────────┐
│ 3. Resolve Dependencies                             │
│    orchestrator → config-manager, deploy-manager    │
└─────────────────────────────────────────────────────┘
             ↓
┌─────────────────────────────────────────────────────┐
│ 4. Download .whl Files                              │
│    openproject_config_manager-3.0.0-py3-none-any.whl│
│    openproject_deploy_manager-2.0.0-py3-none-any.whl│
│    openproject_orchestrator-2.0.0-py3-none-any.whl  │
└─────────────────────────────────────────────────────┘
             ↓
┌─────────────────────────────────────────────────────┐
│ 5. Install in Order                                 │
│    site-packages/openproject_config_manager/        │
│    site-packages/openproject_deploy_manager/        │
│    site-packages/openproject_orchestrator/          │
└─────────────────────────────────────────────────────┘
```

**They work exactly the same way!**

## Migration Path

```
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: Extract config-manager (Proof of Concept)         │
├─────────────────────────────────────────────────────────────┤
│ 1. Create standalone repo                                   │
│ 2. Set up develop/build/main branches                       │
│ 3. Add build workflow                                       │
│ 4. Create first release (v3.0.0)                           │
│ 5. Update orchestrator to use package                       │
│ 6. Remove submodule from orchestrator                       │
│ 7. Test end-to-end                                          │
│                                                             │
│ Time: 2-4 hours                                             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 2: Extract remaining submodules                       │
├─────────────────────────────────────────────────────────────┤
│ Repeat for:                                                 │
│ - deploy-manager                                            │
│ - prober                                                    │
│ - control-flow                                              │
│ - dependency-manager                                        │
│ - tui-form-designer                                         │
│                                                             │
│ Time: 1-2 hours each (using template)                       │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 3: Clean up orchestrator                              │
├─────────────────────────────────────────────────────────────┤
│ 1. Remove all git submodules                                │
│ 2. Delete external/ directory                               │
│ 3. Remove sys.path manipulation code                        │
│ 4. Update imports (should work unchanged)                   │
│ 5. Test full workflow                                       │
│ 6. Update documentation                                     │
│                                                             │
│ Time: 2-3 hours                                             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ ✓ Complete: Clean multi-repo architecture                  │
│                                                             │
│ Result:                                                     │
│ - 7 independent repos                                       │
│ - Each with own release cycle                               │
│ - Standard pip package management                           │
│ - No submodules                                             │
│ - Production-ready packaging                                │
└─────────────────────────────────────────────────────────────┘
```

## Summary

### The Answer to Your Question:

**"How do Linux repos handle Python packages downloaded with pip?"**

They don't include them in the repository at all!

Instead:
1. **Metadata** in `pyproject.toml` declares dependencies
2. **pip** downloads packages from PyPI/GitHub when needed
3. **Packages** are installed to `site-packages/` (outside repo)
4. **Git** only tracks your source code, not dependencies

### Your Repos Should:

1. **Each component** = separate repo with own release cycle
2. **Build branch** = creates wheel and GitHub release
3. **Main orchestrator** = declares dependencies in `pyproject.toml`
4. **pip** = handles everything automatically

### No More:
- ✗ Git submodules
- ✗ sys.path manipulation  
- ✗ Manual dependency syncing
- ✗ Coordinated multi-repo commits

### Instead:
- ✓ Standard Python packages
- ✓ Semantic versioning
- ✓ Independent releases
- ✓ pip does the work
