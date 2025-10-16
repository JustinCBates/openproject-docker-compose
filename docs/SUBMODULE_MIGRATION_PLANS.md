# Submodule Migration Plans - Dual Environment Support

**Created**: October 16, 2025  
**Purpose**: Migration plans for each submodule to support both development (git submodule) and production (pip package) environments  
**Related**: PACKAGE_FILE_MANAGEMENT.md, MAIN_PROJECT_TUI_PROPOSAL.md

---

## Overview

Each submodule must support **two operational modes**:

| Mode | Environment | File Locations | Use Case |
|------|-------------|----------------|----------|
| **Development** | Git submodule | Local directories (`./config/`, `./templates/`) | Active development, testing |
| **Production** | Pip package | Paths provided as parameters | Deployed systems, end users |

**Key Principle**: The API must work identically in both modes.

---

## Common Pattern for All Submodules

### Dual-Mode API Design

```python
from pathlib import Path
from typing import Optional
import os

class SubmoduleComponent:
    """
    Example component with dual-mode support
    """
    
    def __init__(
        self,
        # Production mode: Paths provided by orchestrator
        output_dir: Optional[Path] = None,
        input_dir: Optional[Path] = None,
        cache_dir: Optional[Path] = None,
        
        # Development mode: Use environment variable or default to local
        use_local_paths: Optional[bool] = None,
    ):
        """
        Initialize with automatic mode detection
        
        Args:
            output_dir: Where to write output files (None = auto-detect)
            input_dir: Where to find input files (None = auto-detect)
            cache_dir: Where to cache data (None = auto-detect)
            use_local_paths: Force local development mode (None = auto-detect)
        """
        # Auto-detect mode
        if use_local_paths is None:
            use_local_paths = self._is_development_mode()
        
        if use_local_paths:
            # Development mode: Use local directories
            base_dir = Path(__file__).parent.parent
            self.output_dir = output_dir or base_dir / 'config'
            self.input_dir = input_dir or base_dir / 'data'
            self.cache_dir = cache_dir or base_dir / 'cache'
        else:
            # Production mode: Paths must be provided
            if output_dir is None:
                raise ValueError(
                    "output_dir required in production mode. "
                    "Set use_local_paths=True for development mode."
                )
            self.output_dir = Path(output_dir)
            self.input_dir = Path(input_dir) if input_dir else self.output_dir
            self.cache_dir = Path(cache_dir) if cache_dir else self.output_dir / 'cache'
        
        # Ensure directories exist
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
    
    @staticmethod
    def _is_development_mode() -> bool:
        """
        Auto-detect if running in development mode
        
        Checks for:
        1. Environment variable OPENPROJECT_DEV_MODE
        2. Presence of .git directory
        3. Running from source tree (not site-packages)
        """
        # Check environment variable
        if os.getenv('OPENPROJECT_DEV_MODE', '').lower() in ('1', 'true', 'yes'):
            return True
        
        # Check if running from git repository
        current_file = Path(__file__).resolve()
        
        # Walk up looking for .git directory
        for parent in current_file.parents:
            if (parent / '.git').exists():
                return True
            # Stop at site-packages
            if 'site-packages' in str(parent):
                return False
        
        return False
```

---

## Migration Plan 1: config-manager

**Repository**: `/opt/openproject/external/config-manager`  
**Current State**: Assumes local directory structure  
**Target State**: Support both local and provided paths

### Phase 1: Add Path Parameters (Week 1)

**File**: `src/openproject_config_manager/config_manager.py`

**Current Code**:
```python
class ConfigurationManager:
    def __init__(self, template: str = "openproject"):
        self.template = template
        self.output_dir = Path.cwd() / 'config'  # ← Hardcoded
        self.cache_dir = Path.cwd() / 'cache'    # ← Hardcoded
```

**Updated Code**:
```python
from typing import Optional
from pathlib import Path
import os

class ConfigurationManager:
    """
    Configuration Manager with dual-mode support
    
    Development Mode:
        mgr = ConfigurationManager(template="openproject")
        # Uses local ./config/ and ./cache/ directories
    
    Production Mode:
        mgr = ConfigurationManager(
            template="openproject",
            output_dir=Path("/opt/openproject/config"),
            cache_dir=Path("/opt/openproject/.openproject/cache")
        )
        # Uses provided paths
    """
    
    def __init__(
        self,
        template: str = "openproject",
        output_dir: Optional[Path] = None,
        defaults_file: Optional[Path] = None,
        cache_dir: Optional[Path] = None,
        use_local_paths: Optional[bool] = None,
    ):
        """
        Initialize configuration manager
        
        Args:
            template: Configuration template name
            output_dir: Where to write .env and .cfg files
            defaults_file: Path to defaults.yml
            cache_dir: Where to cache discovery results
            use_local_paths: Force development mode (auto-detected if None)
        """
        self.template = template
        
        # Auto-detect mode
        if use_local_paths is None:
            use_local_paths = self._is_development_mode()
        
        if use_local_paths:
            # Development mode: Use local directories
            base_dir = Path(__file__).parent.parent
            self.output_dir = output_dir or base_dir / 'config'
            self.cache_dir = cache_dir or base_dir / 'cache'
            self.defaults_file = defaults_file or base_dir / 'config' / 'defaults.yml'
        else:
            # Production mode: Paths must be provided
            if output_dir is None:
                raise ValueError(
                    "output_dir required in production mode. "
                    "For development, set use_local_paths=True or "
                    "set environment variable OPENPROJECT_DEV_MODE=1"
                )
            self.output_dir = Path(output_dir)
            self.cache_dir = Path(cache_dir) if cache_dir else self.output_dir / 'cache'
            self.defaults_file = defaults_file  # Optional in production
        
        # Ensure directories exist
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        
        # Load defaults
        if self.defaults_file and self.defaults_file.exists():
            self.defaults = self._load_defaults(self.defaults_file)
        else:
            self.defaults = self._get_builtin_defaults()
    
    @staticmethod
    def _is_development_mode() -> bool:
        """Detect if running in development mode"""
        # Check environment variable
        if os.getenv('OPENPROJECT_DEV_MODE', '').lower() in ('1', 'true', 'yes'):
            return True
        
        # Check if running from git repository
        current_file = Path(__file__).resolve()
        for parent in current_file.parents:
            if (parent / '.git').exists():
                return True
            if 'site-packages' in str(parent):
                return False
        
        return False
    
    def run_interactive(
        self,
        prober_enabled: bool = True,
        resume: bool = False
    ) -> ConfigResult:
        """
        Run interactive configuration workflow
        
        Outputs written to self.output_dir (works in both modes)
        """
        # All file operations use self.output_dir, self.cache_dir
        # No changes needed to core logic
        pass
```

### Phase 2: Update Tests (Week 1)

**File**: `tests/test_config_manager.py`

```python
import pytest
from pathlib import Path
import tempfile
from openproject_config_manager import ConfigurationManager

def test_development_mode():
    """Test development mode with local directories"""
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        
        # Development mode: use_local_paths=True
        mgr = ConfigurationManager(
            template="openproject",
            use_local_paths=True
        )
        
        # Should use local directories
        assert mgr.output_dir.exists()
        assert mgr.cache_dir.exists()

def test_production_mode():
    """Test production mode with provided paths"""
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        output_dir = tmpdir / 'config'
        cache_dir = tmpdir / 'cache'
        
        # Production mode: provide paths
        mgr = ConfigurationManager(
            template="openproject",
            output_dir=output_dir,
            cache_dir=cache_dir,
            use_local_paths=False
        )
        
        # Should use provided paths
        assert mgr.output_dir == output_dir
        assert mgr.cache_dir == cache_dir
        assert output_dir.exists()
        assert cache_dir.exists()

def test_production_mode_requires_paths():
    """Test that production mode requires output_dir"""
    with pytest.raises(ValueError, match="output_dir required"):
        ConfigurationManager(
            template="openproject",
            use_local_paths=False  # Production mode
            # Missing output_dir → should raise
        )

def test_auto_detect_development():
    """Test automatic detection of development mode"""
    import os
    
    # Set environment variable
    os.environ['OPENPROJECT_DEV_MODE'] = '1'
    
    try:
        mgr = ConfigurationManager(template="openproject")
        # Should auto-detect development mode
        assert mgr._is_development_mode() is True
    finally:
        del os.environ['OPENPROJECT_DEV_MODE']
```

### Phase 3: Update Documentation (Week 1)

**File**: `README.md`

Add section:
```markdown
## Usage Modes

### Development Mode (Git Submodule)

```python
from openproject_config_manager import ConfigurationManager

# Auto-detects development mode (looks for .git directory)
mgr = ConfigurationManager(template="openproject")

# Or explicitly enable development mode
mgr = ConfigurationManager(template="openproject", use_local_paths=True)

# Uses local directories:
# - ./config/ for outputs
# - ./cache/ for cached data
```

### Production Mode (Pip Package)

```python
from pathlib import Path
from openproject_config_manager import ConfigurationManager

# Provide paths explicitly
mgr = ConfigurationManager(
    template="openproject",
    output_dir=Path("/opt/openproject/config"),
    cache_dir=Path("/opt/openproject/.openproject/cache"),
    defaults_file=Path("/opt/openproject/config/defaults.yml")
)

# All outputs written to provided directories
```

### Environment Variables

- `OPENPROJECT_DEV_MODE=1`: Force development mode
```

### Migration Checklist

- [ ] Update `ConfigurationManager.__init__()` with path parameters
- [ ] Add `_is_development_mode()` static method
- [ ] Update all file operations to use `self.output_dir`, `self.cache_dir`
- [ ] Add tests for both modes
- [ ] Update README with usage examples
- [ ] Test in development (git submodule)
- [ ] Test in production (after packaging)
- [ ] Update version to 2.0.0 in `pyproject.toml`

---

## Migration Plan 2: deploy-manager

**Repository**: `/opt/openproject/external/deploy-manager`  
**Current State**: Assumes local directory structure  
**Target State**: Support both local and provided paths

### Phase 1: Add Path Parameters (Week 2)

**File**: `src/openproject_deploy_manager/deployment_orchestrator.py`

**Current Code**:
```python
class DeploymentOrchestrator:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.templates_dir = Path.cwd() / 'templates'  # ← Hardcoded
        self.output_dir = Path.cwd() / 'outputs'       # ← Hardcoded
```

**Updated Code**:
```python
from typing import Optional, Dict, Any
from pathlib import Path
import os

class DeploymentOrchestrator:
    """
    Deployment Orchestrator with dual-mode support
    
    Development Mode:
        deployer = DeploymentOrchestrator(config=cfg)
        # Uses local ./templates/ and ./outputs/
    
    Production Mode:
        deployer = DeploymentOrchestrator(
            config=cfg,
            templates_dir=Path("/opt/openproject/templates"),
            output_dir=Path("/opt/openproject/outputs"),
            compose_file=Path("/opt/openproject/docker-compose.yml")
        )
    """
    
    def __init__(
        self,
        config: Dict[str, Any],
        config_file: Optional[Path] = None,
        templates_dir: Optional[Path] = None,
        output_dir: Optional[Path] = None,
        compose_file: Optional[Path] = None,
        snapshot_dir: Optional[Path] = None,
        use_local_paths: Optional[bool] = None,
    ):
        """
        Initialize deployment orchestrator
        
        Args:
            config: Configuration dictionary
            config_file: Path to config file (.env or .cfg)
            templates_dir: Where to find Jinja2 templates
            output_dir: Where to write rendered files
            compose_file: Path to docker-compose.yml
            snapshot_dir: Where to store deployment snapshots
            use_local_paths: Force development mode (auto-detected if None)
        """
        self.config = config
        self.config_file = config_file
        
        # Auto-detect mode
        if use_local_paths is None:
            use_local_paths = self._is_development_mode()
        
        if use_local_paths:
            # Development mode: Use local directories
            base_dir = Path(__file__).parent.parent
            self.templates_dir = templates_dir or base_dir / 'templates'
            self.output_dir = output_dir or base_dir / 'outputs'
            self.compose_file = compose_file or base_dir / 'docker-compose.yml'
            self.snapshot_dir = snapshot_dir or base_dir / 'backups' / 'snapshots'
        else:
            # Production mode: Paths must be provided
            if templates_dir is None or output_dir is None:
                raise ValueError(
                    "templates_dir and output_dir required in production mode. "
                    "For development, set use_local_paths=True or "
                    "set environment variable OPENPROJECT_DEV_MODE=1"
                )
            self.templates_dir = Path(templates_dir)
            self.output_dir = Path(output_dir)
            self.compose_file = Path(compose_file) if compose_file else Path.cwd() / 'docker-compose.yml'
            self.snapshot_dir = Path(snapshot_dir) if snapshot_dir else self.output_dir / 'snapshots'
        
        # Ensure directories exist
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.snapshot_dir.mkdir(parents=True, exist_ok=True)
        
        # Verify templates directory exists
        if not self.templates_dir.exists():
            raise ValueError(f"Templates directory not found: {self.templates_dir}")
    
    @staticmethod
    def _is_development_mode() -> bool:
        """Detect if running in development mode"""
        if os.getenv('OPENPROJECT_DEV_MODE', '').lower() in ('1', 'true', 'yes'):
            return True
        
        current_file = Path(__file__).resolve()
        for parent in current_file.parents:
            if (parent / '.git').exists():
                return True
            if 'site-packages' in str(parent):
                return False
        
        return False
    
    def render_templates(self) -> TemplateResult:
        """
        Render Jinja2 templates
        
        Works in both modes - uses self.templates_dir and self.output_dir
        """
        from jinja2 import Environment, FileSystemLoader
        
        # Create Jinja2 environment
        env = Environment(loader=FileSystemLoader(self.templates_dir))
        
        # Render templates
        templates = self._discover_templates()
        
        for template_name in templates:
            template = env.get_template(template_name)
            rendered = template.render(**self.config)
            
            # Write to output_dir
            output_file = self.output_dir / template_name.replace('.j2', '')
            output_file.write_text(rendered)
        
        return TemplateResult(success=True, files_rendered=len(templates))
    
    def _discover_templates(self) -> list[str]:
        """Discover templates in templates_dir"""
        return [f.name for f in self.templates_dir.glob('*.j2')]
```

### Phase 2: Update Tests (Week 2)

**File**: `tests/test_deployment_orchestrator.py`

```python
import pytest
from pathlib import Path
import tempfile
from openproject_deploy_manager import DeploymentOrchestrator

@pytest.fixture
def sample_config():
    return {
        'domain': 'openproject.example.com',
        'postgres_password': 'secret123',
    }

def test_development_mode(sample_config):
    """Test development mode"""
    deployer = DeploymentOrchestrator(
        config=sample_config,
        use_local_paths=True
    )
    
    # Should use local directories
    assert deployer.templates_dir.exists()
    assert deployer.output_dir.exists()

def test_production_mode(sample_config):
    """Test production mode with provided paths"""
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        
        templates_dir = tmpdir / 'templates'
        output_dir = tmpdir / 'outputs'
        templates_dir.mkdir()
        
        # Create dummy template
        (templates_dir / 'test.j2').write_text('Domain: {{ domain }}')
        
        deployer = DeploymentOrchestrator(
            config=sample_config,
            templates_dir=templates_dir,
            output_dir=output_dir,
            use_local_paths=False
        )
        
        # Should use provided paths
        assert deployer.templates_dir == templates_dir
        assert deployer.output_dir == output_dir
        assert output_dir.exists()

def test_production_mode_requires_paths(sample_config):
    """Test that production mode requires paths"""
    with pytest.raises(ValueError, match="templates_dir and output_dir required"):
        DeploymentOrchestrator(
            config=sample_config,
            use_local_paths=False
        )
```

### Migration Checklist

- [ ] Update `DeploymentOrchestrator.__init__()` with path parameters
- [ ] Add `_is_development_mode()` static method
- [ ] Update all file operations to use instance paths
- [ ] Add tests for both modes
- [ ] Update README with usage examples
- [ ] Test template rendering in both modes
- [ ] Test Docker operations in both modes
- [ ] Update version to 2.0.0 in `pyproject.toml`

---

## Migration Plan 3: tui-form-designer

**Repository**: `/opt/openproject/external/tui-form-designer`  
**Current State**: Minimal path assumptions  
**Target State**: Fully support both modes

### Phase 1: Add Path Parameters (Week 3)

**File**: `src/tui_form_designer/form_designer.py`

**Current Code**:
```python
class FormDesigner:
    def __init__(self):
        self.forms = []
```

**Updated Code**:
```python
from typing import Optional
from pathlib import Path
import os

class FormDesigner:
    """
    TUI Form Designer with dual-mode support
    
    Minimal path requirements - mostly just for saving/loading forms
    """
    
    def __init__(
        self,
        forms_dir: Optional[Path] = None,
        cache_dir: Optional[Path] = None,
        use_local_paths: Optional[bool] = None,
    ):
        """
        Initialize form designer
        
        Args:
            forms_dir: Where to save/load form definitions
            cache_dir: Where to cache form state
            use_local_paths: Force development mode (auto-detected if None)
        """
        # Auto-detect mode
        if use_local_paths is None:
            use_local_paths = self._is_development_mode()
        
        if use_local_paths:
            # Development mode
            base_dir = Path(__file__).parent.parent
            self.forms_dir = forms_dir or base_dir / 'forms'
            self.cache_dir = cache_dir or base_dir / 'cache'
        else:
            # Production mode (forms_dir optional - can work in-memory)
            self.forms_dir = Path(forms_dir) if forms_dir else None
            self.cache_dir = Path(cache_dir) if cache_dir else None
        
        # Create directories if specified
        if self.forms_dir:
            self.forms_dir.mkdir(parents=True, exist_ok=True)
        if self.cache_dir:
            self.cache_dir.mkdir(parents=True, exist_ok=True)
        
        self.forms = []
    
    @staticmethod
    def _is_development_mode() -> bool:
        """Detect development mode"""
        if os.getenv('OPENPROJECT_DEV_MODE', '').lower() in ('1', 'true', 'yes'):
            return True
        
        current_file = Path(__file__).resolve()
        for parent in current_file.parents:
            if (parent / '.git').exists():
                return True
            if 'site-packages' in str(parent):
                return False
        
        return False
    
    def save_form(self, form_name: str, form_data: dict):
        """Save form to disk (if forms_dir is configured)"""
        if self.forms_dir is None:
            raise ValueError("forms_dir not configured - cannot save forms")
        
        form_file = self.forms_dir / f"{form_name}.json"
        form_file.write_text(json.dumps(form_data, indent=2))
    
    def load_form(self, form_name: str) -> dict:
        """Load form from disk (if forms_dir is configured)"""
        if self.forms_dir is None:
            raise ValueError("forms_dir not configured - cannot load forms")
        
        form_file = self.forms_dir / f"{form_name}.json"
        return json.loads(form_file.read_text())
```

### Migration Checklist

- [ ] Update `FormDesigner.__init__()` with path parameters
- [ ] Add `_is_development_mode()` static method
- [ ] Update save/load operations
- [ ] Add tests for both modes
- [ ] Update README
- [ ] Test with control-flow's Interactive UI Library
- [ ] Update version to 1.0.0 in `pyproject.toml`

---

## Migration Plan 4: prober

**Repository**: `/opt/openproject/external/prober`  
**Current State**: Network-based, minimal file I/O  
**Target State**: Support optional cache directory

### Phase 1: Add Optional Cache Support (Week 3)

**File**: `src/prober/prober.py`

```python
from typing import Optional
from pathlib import Path
import os

class Prober:
    """
    System prober with dual-mode support
    
    Minimal path requirements - cache is optional
    """
    
    def __init__(
        self,
        cache_dir: Optional[Path] = None,
        use_local_paths: Optional[bool] = None,
    ):
        """
        Initialize prober
        
        Args:
            cache_dir: Where to cache probe results (optional)
            use_local_paths: Force development mode
        """
        # Auto-detect mode
        if use_local_paths is None:
            use_local_paths = self._is_development_mode()
        
        if use_local_paths:
            base_dir = Path(__file__).parent.parent
            self.cache_dir = cache_dir or base_dir / 'cache'
        else:
            self.cache_dir = Path(cache_dir) if cache_dir else None
        
        # Create cache directory if specified
        if self.cache_dir:
            self.cache_dir.mkdir(parents=True, exist_ok=True)
    
    @staticmethod
    def _is_development_mode() -> bool:
        """Detect development mode"""
        if os.getenv('OPENPROJECT_DEV_MODE', '').lower() in ('1', 'true', 'yes'):
            return True
        
        current_file = Path(__file__).resolve()
        for parent in current_file.parents:
            if (parent / '.git').exists():
                return True
            if 'site-packages' in str(parent):
                return False
        
        return False
```

### Migration Checklist

- [ ] Add optional `cache_dir` parameter
- [ ] Add `_is_development_mode()` static method
- [ ] Update tests
- [ ] Update README
- [ ] Update version in `pyproject.toml`

---

## Migration Plan 5: control-flow

**Repository**: `/opt/openproject/external/control-flow`  
**Current State**: YAML-based, assumes local workflows  
**Target State**: Support provided workflow directory

### Phase 1: Add Workflow Directory Parameter (Week 4)

**File**: `src/control_flow/flow_engine.py`

```python
from typing import Optional
from pathlib import Path
import os

class FlowEngine:
    """
    Workflow engine with dual-mode support
    """
    
    def __init__(
        self,
        workflows_dir: Optional[Path] = None,
        cache_dir: Optional[Path] = None,
        use_local_paths: Optional[bool] = None,
    ):
        """
        Initialize flow engine
        
        Args:
            workflows_dir: Where to find workflow YAML files
            cache_dir: Where to cache workflow state
            use_local_paths: Force development mode
        """
        # Auto-detect mode
        if use_local_paths is None:
            use_local_paths = self._is_development_mode()
        
        if use_local_paths:
            base_dir = Path(__file__).parent.parent
            self.workflows_dir = workflows_dir or base_dir / 'workflows'
            self.cache_dir = cache_dir or base_dir / 'cache'
        else:
            if workflows_dir is None:
                raise ValueError("workflows_dir required in production mode")
            self.workflows_dir = Path(workflows_dir)
            self.cache_dir = Path(cache_dir) if cache_dir else self.workflows_dir / 'cache'
        
        # Ensure directories exist
        self.workflows_dir.mkdir(parents=True, exist_ok=True)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
    
    @staticmethod
    def _is_development_mode() -> bool:
        """Detect development mode"""
        if os.getenv('OPENPROJECT_DEV_MODE', '').lower() in ('1', 'true', 'yes'):
            return True
        
        current_file = Path(__file__).resolve()
        for parent in current_file.parents:
            if (parent / '.git').exists():
                return True
            if 'site-packages' in str(parent):
                return False
        
        return False
```

### Migration Checklist

- [ ] Update `FlowEngine.__init__()` with path parameters
- [ ] Add `_is_development_mode()` static method
- [ ] Update workflow loading to use `workflows_dir`
- [ ] Add tests for both modes
- [ ] Update README
- [ ] Update version to 3.0.0 in `pyproject.toml`

---

## Migration Plan 6: dependency-manager

**Repository**: `/opt/openproject/external/dependency-manager`  
**Current State**: Script-based, minimal structure  
**Target State**: Support both modes

### Phase 1: Package as Library (Week 4)

**File**: `src/dependency_manager/dependency_manager.py`

```python
from typing import Optional
from pathlib import Path
import os

class DependencyManager:
    """
    Dependency manager with dual-mode support
    """
    
    def __init__(
        self,
        requirements_file: Optional[Path] = None,
        cache_dir: Optional[Path] = None,
        use_local_paths: Optional[bool] = None,
    ):
        """
        Initialize dependency manager
        
        Args:
            requirements_file: Path to requirements.txt or pyproject.toml
            cache_dir: Where to cache dependency data
            use_local_paths: Force development mode
        """
        # Auto-detect mode
        if use_local_paths is None:
            use_local_paths = self._is_development_mode()
        
        if use_local_paths:
            base_dir = Path(__file__).parent.parent
            self.requirements_file = requirements_file or base_dir / 'requirements.txt'
            self.cache_dir = cache_dir or base_dir / 'cache'
        else:
            self.requirements_file = Path(requirements_file) if requirements_file else None
            self.cache_dir = Path(cache_dir) if cache_dir else None
        
        # Create cache if specified
        if self.cache_dir:
            self.cache_dir.mkdir(parents=True, exist_ok=True)
    
    @staticmethod
    def _is_development_mode() -> bool:
        """Detect development mode"""
        if os.getenv('OPENPROJECT_DEV_MODE', '').lower() in ('1', 'true', 'yes'):
            return True
        
        current_file = Path(__file__).resolve()
        for parent in current_file.parents:
            if (parent / '.git').exists():
                return True
            if 'site-packages' in str(parent):
                return False
        
        return False
```

### Migration Checklist

- [ ] Create `DependencyManager` class
- [ ] Add `_is_development_mode()` static method
- [ ] Refactor scripts into library methods
- [ ] Add tests for both modes
- [ ] Update README
- [ ] Create `pyproject.toml` for packaging

---

## Testing Strategy

### Development Mode Testing

For each submodule, create `tests/test_development_mode.py`:

```python
import pytest
import os
from pathlib import Path

@pytest.fixture(autouse=True)
def setup_dev_mode():
    """Force development mode for tests"""
    os.environ['OPENPROJECT_DEV_MODE'] = '1'
    yield
    del os.environ['OPENPROJECT_DEV_MODE']

def test_auto_detect_development():
    """Test that development mode is auto-detected"""
    from openproject_MODULE_NAME import MainClass
    
    obj = MainClass()
    assert obj._is_development_mode() is True

def test_uses_local_directories():
    """Test that local directories are used"""
    from openproject_MODULE_NAME import MainClass
    
    obj = MainClass()
    
    # Should use local directories
    assert 'site-packages' not in str(obj.output_dir)
    assert obj.output_dir.exists()
```

### Production Mode Testing

For each submodule, create `tests/test_production_mode.py`:

```python
import pytest
import tempfile
from pathlib import Path

def test_production_mode_requires_paths():
    """Test that production mode requires explicit paths"""
    from openproject_MODULE_NAME import MainClass
    
    with pytest.raises(ValueError, match="required in production mode"):
        MainClass(use_local_paths=False)

def test_production_mode_with_paths():
    """Test production mode with provided paths"""
    from openproject_MODULE_NAME import MainClass
    
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        
        obj = MainClass(
            output_dir=tmpdir / 'output',
            use_local_paths=False
        )
        
        assert obj.output_dir == tmpdir / 'output'
        assert obj.output_dir.exists()
```

---

## Integration Testing

### Test Script for Dual-Mode Operation

**File**: `tests/integration/test_dual_mode.sh`

```bash
#!/bin/bash
set -e

echo "Testing Dual-Mode Operation for All Submodules"
echo "==============================================="

SUBMODULES=(
    "config-manager"
    "deploy-manager"
    "tui-form-designer"
    "prober"
    "control-flow"
    "dependency-manager"
)

for module in "${SUBMODULES[@]}"; do
    echo ""
    echo "Testing: $module"
    echo "-----------------------------------"
    
    cd "/opt/openproject/external/$module"
    
    # Test development mode
    echo "✓ Testing development mode..."
    export OPENPROJECT_DEV_MODE=1
    pytest tests/test_development_mode.py -v
    unset OPENPROJECT_DEV_MODE
    
    # Test production mode
    echo "✓ Testing production mode..."
    pytest tests/test_production_mode.py -v
    
    echo "✅ $module passed all tests"
done

echo ""
echo "==============================================="
echo "✅ All submodules passed dual-mode tests!"
```

---

## Environment Variable Reference

| Variable | Values | Effect |
|----------|--------|--------|
| `OPENPROJECT_DEV_MODE` | `1`, `true`, `yes` | Force development mode (use local paths) |
| `OPENPROJECT_WORKSPACE` | Path | Set workspace directory for production |

**Usage**:
```bash
# Development
export OPENPROJECT_DEV_MODE=1
python -c "from openproject_config_manager import ConfigurationManager; mgr = ConfigurationManager()"

# Production
export OPENPROJECT_WORKSPACE=/opt/openproject
python -c "from openproject_config_manager import ConfigurationManager; mgr = ConfigurationManager(output_dir='/opt/openproject/config')"
```

---

## Migration Timeline

| Week | Submodules | Tasks |
|------|-----------|-------|
| **Week 1** | config-manager | Add path parameters, tests, docs |
| **Week 2** | deploy-manager | Add path parameters, tests, docs |
| **Week 3** | tui-form-designer, prober | Add path parameters, tests |
| **Week 4** | control-flow, dependency-manager | Add path parameters, tests |
| **Week 5** | All | Integration testing, bug fixes |
| **Week 6** | All | Documentation, examples, release prep |

---

## Success Criteria

For each submodule to be considered "migrated":

- ✅ Supports both development and production modes
- ✅ Auto-detects mode (via `.git` or environment variable)
- ✅ Raises clear errors if production mode missing paths
- ✅ All tests pass in both modes
- ✅ README documents both usage patterns
- ✅ Version bumped appropriately (semantic versioning)
- ✅ Integration test passes with orchestrator

---

**Status**: Migration plans complete for all 6 submodules  
**Next**: Begin Week 1 - migrate config-manager
