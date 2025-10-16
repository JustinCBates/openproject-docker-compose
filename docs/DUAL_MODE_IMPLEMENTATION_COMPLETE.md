# Dual-Mode Implementation Complete - Config-Manager & Deploy-Manager

**Date**: October 16, 2025  
**Status**: ✅ Complete  
**Version**: 2.0.0 for both packages

---

## Summary

Both `config-manager` and `deploy-manager` now support **dual-mode operation**:
- **Development Mode**: Git submodule with local directory structure
- **Production Mode**: Pip-installable package receiving paths from orchestrator

---

## Changes Made

### Config-Manager (v0.1.0 → v2.0.0)

**Commit**: `25bd8a7`

**Files Modified**:
- `src/openproject_config_manager/core/manager.py` (+120 lines)
  - Added path parameters: `output_dir`, `cache_dir`, `flows_dir`, `use_local_paths`
  - Implemented `_is_development_mode()` auto-detection
  - Updated all file operations to use `self.output_dir`, `self.cache_dir`
  - Environment variable support: `OPENPROJECT_DEV_MODE=1`

- `src/openproject_config_manager/__init__.py`
  - Updated version to 2.0.0
  - Added dual-mode documentation

- `pyproject.toml`
  - Updated version to 2.0.0
  - Updated description

**Files Created**:
- `tests/test_development_mode.py` (6 tests)
- `tests/test_production_mode.py` (8 tests)

**API Examples**:

```python
# Development mode (auto-detected)
from openproject_config_manager import ConfigurationManager

mgr = ConfigurationManager()  # Uses ./output/ and ./cache/

# Production mode (explicit paths)
mgr = ConfigurationManager(
    output_dir=Path("/opt/openproject/config"),
    cache_dir=Path("/opt/openproject/.openproject/cache")
)
```

---

### Deploy-Manager (Initial → v2.0.0)

**Commit**: `cfe92a7`

**Files Created**:
- `pyproject.toml` - Full package configuration
- `src/openproject_deploy_manager/__init__.py` - Package exports
- `src/openproject_deploy_manager/deployment_orchestrator.py` (+250 lines)
  - DeploymentOrchestrator class with dual-mode support
  - `render_templates()` method
  - `create_snapshot()` method
  - `deploy()` wrapper
  - `_is_development_mode()` auto-detection

**Tests Created**:
- `tests/test_development_mode.py` (6 tests)
- `tests/test_production_mode.py` (9 tests)

**API Examples**:

```python
# Development mode (auto-detected)
from openproject_deploy_manager import DeploymentOrchestrator

deployer = DeploymentOrchestrator(config=cfg)  # Uses ./templates/ and ./outputs/

# Production mode (explicit paths)
deployer = DeploymentOrchestrator(
    config=cfg,
    templates_dir=Path("/opt/openproject/templates"),
    output_dir=Path("/opt/openproject/outputs"),
    compose_file=Path("/opt/openproject/docker-compose.yml")
)

# Render templates
result = deployer.render_templates()

# Create snapshot
result = deployer.create_snapshot("pre_deploy")
```

---

## Auto-Detection Logic

Both packages use identical auto-detection:

```python
@staticmethod
def _is_development_mode() -> bool:
    """
    Auto-detect development vs production mode.
    
    Checks (in order):
    1. OPENPROJECT_DEV_MODE environment variable
    2. Presence of .git directory (git repo)
    3. Not in site-packages (pip package)
    """
    # Check 1: Environment variable
    if os.getenv('OPENPROJECT_DEV_MODE') in ('1', 'true', 'yes'):
        return True
    
    # Check 2: Git repository
    current_file = Path(__file__).resolve()
    for parent in current_file.parents:
        if (parent / '.git').exists():
            return True
        if 'site-packages' in str(parent):
            return False
    
    # Default: development
    return True
```

---

## Testing Status

### Config-Manager Tests

**Development Mode** (6 tests):
- ✅ Auto-detect development mode
- ✅ Uses local directories
- ✅ Explicit development mode flag
- ✅ Custom paths in development
- ✅ Flow engine initialization
- ✅ Environment variable detection

**Production Mode** (8 tests):
- ✅ Requires output_dir parameter
- ✅ Uses provided paths
- ✅ Cache defaults to output_dir/cache
- ✅ Project root derived from output_dir
- ✅ All paths explicitly specified
- ✅ Enhanced defaults written to output_dir
- ✅ Works without flows_dir
- ✅ Error handling for missing paths

### Deploy-Manager Tests

**Development Mode** (6 tests):
- ✅ Auto-detect development mode
- ✅ Uses local directories
- ✅ Explicit development mode flag
- ✅ Custom paths in development
- ✅ Config paths updated
- ✅ Environment variable detection

**Production Mode** (9 tests):
- ✅ Requires templates_dir and output_dir
- ✅ Uses provided paths
- ✅ Snapshot dir defaults to output_dir/snapshots
- ✅ All paths explicitly specified
- ✅ Template rendering works
- ✅ Snapshot creation works
- ✅ Config paths added
- ✅ Compose file handling
- ✅ Error handling for missing paths

---

## Usage Modes

### Mode 1: Development (Git Submodule)

**Environment**:
- Running from git repository
- `.git` directory present
- Local directory structure

**Usage**:
```python
# Config-manager
mgr = ConfigurationManager()

# Deploy-manager
deployer = DeploymentOrchestrator(config=cfg)
```

**File Locations**:
- Config-manager: `./output/`, `./cache/`
- Deploy-manager: `./templates/`, `./outputs/`, `./backups/`

---

### Mode 2: Production (Pip Package)

**Environment**:
- Installed via pip to `site-packages/`
- No `.git` directory
- Orchestrator provides paths

**Usage**:
```python
# Config-manager
from openproject_config_manager import ConfigurationManager

mgr = ConfigurationManager(
    output_dir=workspace.config_dir,
    cache_dir=workspace.cache_dir
)

# Deploy-manager
from openproject_deploy_manager import DeploymentOrchestrator

deployer = DeploymentOrchestrator(
    config=cfg,
    templates_dir=workspace.templates_dir,
    output_dir=workspace.outputs_dir,
    compose_file=workspace.compose_file
)
```

**File Locations**:
- All paths provided by orchestrator
- Typically: `/opt/openproject/config/`, `/opt/openproject/outputs/`, etc.

---

### Mode 3: Force Development (Override)

**Usage**:
```bash
export OPENPROJECT_DEV_MODE=1
```

Or programmatically:
```python
mgr = ConfigurationManager(use_local_paths=True)
deployer = DeploymentOrchestrator(config=cfg, use_local_paths=True)
```

---

## Building Packages

### Config-Manager

```bash
cd /opt/openproject/external/config-manager

# Install build tools (if needed)
pip install build

# Build wheel
python3 -m build --outdir dist/

# Result: dist/openproject_config_manager-2.0.0-py3-none-any.whl
```

### Deploy-Manager

```bash
cd /opt/openproject/external/deploy-manager

# Install build tools (if needed)
pip install build

# Build wheel
python3 -m build --outdir dist/

# Result: dist/openproject_deploy_manager-2.0.0-py3-none-any.whl
```

---

## Installing Packages

### From Local Wheel

```bash
pip install /opt/openproject/external/config-manager/dist/openproject_config_manager-2.0.0-py3-none-any.whl
pip install /opt/openproject/external/deploy-manager/dist/openproject_deploy_manager-2.0.0-py3-none-any.whl
```

### From Git (Development)

```bash
pip install -e /opt/openproject/external/config-manager
pip install -e /opt/openproject/external/deploy-manager
```

---

## Integration with Main Orchestrator

### Workspace Manager Integration

```python
from openproject_orchestrator.workspace import WorkspaceManager

workspace = WorkspaceManager("/opt/openproject")

# Get paths for config-manager
config_paths = workspace.get_config_manager_paths()
# Returns: {'output_dir': Path(...), 'cache_dir': Path(...), ...}

# Get paths for deploy-manager
deploy_paths = workspace.get_deploy_manager_paths()
# Returns: {'templates_dir': Path(...), 'output_dir': Path(...), ...}
```

### Config Coordinator

```python
from openproject_config_manager import ConfigurationManager

class ConfigCoordinator:
    def __init__(self, workspace: WorkspaceManager):
        self.workspace = workspace
        
    def run_interactive_configuration(self):
        paths = self.workspace.get_config_manager_paths()
        
        mgr = ConfigurationManager(
            output_dir=paths['output_dir'],
            cache_dir=paths['cache_dir']
        )
        
        return mgr.run_interactive()
```

### Deploy Coordinator

```python
from openproject_deploy_manager import DeploymentOrchestrator

class DeployCoordinator:
    def __init__(self, workspace: WorkspaceManager):
        self.workspace = workspace
        
    def deploy(self, config):
        paths = self.workspace.get_deploy_manager_paths()
        
        deployer = DeploymentOrchestrator(
            config=config,
            templates_dir=paths['templates_dir'],
            output_dir=paths['output_dir'],
            compose_file=paths['compose_file']
        )
        
        return deployer.deploy()
```

---

## Environment Variables

| Variable | Values | Effect |
|----------|--------|--------|
| `OPENPROJECT_DEV_MODE` | `1`, `true`, `yes` | Force development mode |
| `OPENPROJECT_WORKSPACE` | Path | Default workspace directory |

**Examples**:

```bash
# Force development mode
export OPENPROJECT_DEV_MODE=1

# Set default workspace
export OPENPROJECT_WORKSPACE=/opt/openproject
```

---

## Breaking Changes

### Config-Manager

**v0.1.0 → v2.0.0**:
- ❌ **Breaking in production mode**: `output_dir` now required (was optional)
- ✅ **Backward compatible in development mode**: Existing code works unchanged
- ✅ **Migration path**: Add `use_local_paths=True` to maintain old behavior

### Deploy-Manager

**Initial → v2.0.0**:
- ❌ **Breaking in production mode**: `templates_dir` and `output_dir` required
- ✅ **Backward compatible in development mode**: Existing code works unchanged
- ✅ **New package structure**: Now pip-installable

---

## Next Steps

1. ✅ **Config-manager dual-mode** - Complete
2. ✅ **Deploy-manager dual-mode** - Complete
3. ⏳ **Update READMEs** - Document dual-mode usage
4. ⏳ **Build wheel packages** - Create distributable packages
5. ⏳ **Test package installation** - Verify pip install works
6. ⏳ **Push to remotes** - Publish changes
7. ⏳ **Implement WorkspaceManager** - Main orchestrator integration
8. ⏳ **Migrate other submodules** - tui-form-designer, prober, control-flow, dependency-manager

---

## Git Commits

### Config-Manager
- **Branch**: develop
- **Commit**: 25bd8a7
- **Message**: "feat: add dual-mode support (Development & Production) - v2.0.0"
- **Files Changed**: 5 files, +340 insertions, -22 deletions

### Deploy-Manager
- **Branch**: develop
- **Commit**: cfe92a7
- **Message**: "feat: add dual-mode support (Development & Production) - v2.0.0"
- **Files Changed**: 6 files, +1133 insertions

---

## Success Criteria

- ✅ Both packages support development mode (auto-detected)
- ✅ Both packages support production mode (explicit paths)
- ✅ Auto-detection works correctly (environment, .git, site-packages)
- ✅ All tests pass (14 tests for config-manager, 15 tests for deploy-manager)
- ✅ Backward compatible in development mode
- ✅ Clear error messages for production mode missing paths
- ✅ Documentation updated (docstrings, commit messages)
- ✅ Version bumped to 2.0.0
- ✅ Package structure created (deploy-manager)
- ✅ Commits made to both repositories

---

**Status**: ✅ **Phase 1 Complete** - Config-manager and Deploy-manager dual-mode support implemented and committed.

**Ready for**: Package building, installation testing, and integration with main orchestrator.
