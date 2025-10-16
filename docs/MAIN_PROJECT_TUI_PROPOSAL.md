# OpenProject Main Orchestrator - Interactive TUI System Proposal

**Created**: October 16, 2025  
**Purpose**: Design the main project's interactive TUI orchestrator that coordinates packaged submodules  
**Status**: Proposal - Ready for Implementation

---

## Executive Summary

This proposal outlines the architecture for the **OpenProject Main Orchestrator** - an interactive terminal UI (TUI) system that provides a unified, user-friendly interface for deploying OpenProject. The orchestrator will coordinate three packaged submodules (config-manager, deploy-manager, tui-form-designer) while providing OpenProject-specific functionality.

### Vision

**One Command to Deploy Everything:**
```bash
openproject deploy
```

This launches an interactive TUI that:
1. ✅ Auto-discovers system environment
2. ✅ Guides user through configuration (with smart defaults)
3. ✅ Validates configuration before deployment
4. ✅ Deploys OpenProject stack
5. ✅ Verifies health and provides status
6. ✅ Offers ongoing maintenance (backup, upgrade, restore)

---

## Architecture Overview

### System Structure

```
┌─────────────────────────────────────────────────────────────────────┐
│                   OpenProject Main Orchestrator                      │
│                        (This Project)                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │               Interactive TUI Controller                    │    │
│  │  (Main Menu → Workflows → Status Dashboard)                 │    │
│  └────────────────┬───────────────────────────────────────────┘    │
│                   │                                                   │
│  ┌────────────────┴──────────────┬────────────────┬─────────────┐  │
│  │                               │                │             │  │
│  ▼                               ▼                ▼             ▼  │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐  ┌────────┐  │
│  │ Config-Mgr   │  │ Deploy-Mgr   │  │   TUI      │  │ Maint  │  │
│  │ Coordinator  │  │ Coordinator  │  │   Forms    │  │ Manager│  │
│  │              │  │              │  │            │  │        │  │
│  └──────┬───────┘  └──────┬───────┘  └─────┬──────┘  └────┬───┘  │
│         │                 │                 │              │       │
└─────────┼─────────────────┼─────────────────┼──────────────┼───────┘
          │                 │                 │              │
          │                 │                 │              │
    ┌─────▼─────┐     ┌─────▼─────┐    ┌────▼─────┐   (Built-in)
    │ config-   │     │ deploy-   │    │   tui-   │
    │ manager   │     │ manager   │    │   form-  │
    │ (package) │     │ (package) │    │ designer │
    │           │     │           │    │ (package)│
    └───────────┘     └───────────┘    └──────────┘
     External PKG      External PKG     External PKG
```

### Package Dependencies

```toml
[project]
name = "openproject-deploy"
version = "2.0.0"
description = "Interactive deployment orchestrator for OpenProject"

dependencies = [
    "rich>=13.0.0",              # TUI framework
    "click>=8.0.0",              # CLI framework
    "pyyaml>=6.0",               # YAML processing
    "docker>=7.0.0",             # Docker SDK
    
    # Packaged submodules (production imports)
    "openproject-config-manager>=2.0.0",
    "openproject-deploy-manager>=2.0.0", 
    "openproject-tui-form-designer>=1.0.0",
    
    # Control-flow for orchestration
    "openproject-control-flow>=2.0.0",
]
```

---

## Component Architecture

### 1. Main TUI Controller

**Location**: `src/openproject_orchestrator/tui_controller.py`

**Purpose**: Primary interactive interface that presents menus and coordinates workflows

**Key Features**:
- Main menu with workflow options
- Live status dashboard
- Progress tracking for long operations
- Error handling and user-friendly messages
- Contextual help system

**Menu Structure**:
```
╔══════════════════════════════════════════════════════════╗
║         OpenProject Deployment Orchestrator              ║
║                    v2.0.0                                ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  [1] 🚀 Quick Deploy   - Guided setup and deployment   ║
║  [2] ⚙️  Configure      - Interactive configuration     ║
║  [3] 📦 Deploy          - Deploy with existing config   ║
║  [4] 💾 Backup          - Backup OpenProject data       [NOT COMPLETE] ║
║  [5] ⬆️  Upgrade        - Upgrade OpenProject version   [NOT COMPLETE] ║
║  [6] 🔄 Restore         - Restore from backup           [NOT COMPLETE] ║
║  [7] 🏥 Health Check    - System health status          [NOT COMPLETE] ║
║  [8] 📊 Status          - Deployment status dashboard   ║
║  [9] 🔧 Maintenance     - Additional tools              [NOT COMPLETE] ║
║  [A] 📁 File Server     - Install file server           [NOT COMPLETE] ║
║  [B] 🔧 Gitea           - Install Gitea (Git hosting)   [NOT COMPLETE] ║
║  [0] ❌ Exit                                             ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
```

**Implementation**:
```python
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn
from phases.libraries.interactive_ui.universal_menu import UniversalMenu
from phases.libraries.interactive_ui.terminal_capabilities import TerminalCapabilities

class TUIController:
    """Main interactive TUI controller"""
    
    def __init__(self):
        self.console = Console()
        self.capabilities = TerminalCapabilities()
        self.menu = UniversalMenu(capabilities=self.capabilities)
        
        # Coordinators for each submodule
        self.config_coordinator = ConfigCoordinator()
        self.deploy_coordinator = DeployCoordinator()
        self.maintenance = MaintenanceManager()
        
    def run(self):
        """Main TUI loop"""
        while True:
            choice = self.show_main_menu()
            
            if choice == "quick_deploy":
                self.workflow_quick_deploy()
            elif choice == "configure":
                self.workflow_configure()
            elif choice == "deploy":
                self.workflow_deploy()
            elif choice == "backup":
                self.workflow_backup()
            elif choice == "upgrade":
                self.workflow_upgrade()
            elif choice == "restore":
                self.workflow_restore()
            elif choice == "health":
                self.workflow_health_check()
            elif choice == "status":
                self.show_status_dashboard()
            elif choice == "maintenance":
                self.show_maintenance_menu()
            elif choice == "exit":
                self.console.print("[green]Goodbye![/green]")
                break
    
    def show_main_menu(self):
        """Display main menu and get user choice"""
        choices = [
            MenuChoice(
                value="quick_deploy",
                title="🚀 Quick Deploy",
                description="Guided setup and deployment (recommended)"
            ),
            MenuChoice(
                value="configure",
                title="⚙️  Configure",
                description="Interactive configuration without deployment"
            ),
            MenuChoice(
                value="deploy",
                title="📦 Deploy",
                description="Deploy with existing configuration"
            ),
            MenuChoice(
                value="backup",
                title="💾 Backup [NOT COMPLETE]",
                description="Backup OpenProject data and configuration (BACKLOG)",
                disabled=True
            ),
            MenuChoice(
                value="upgrade",
                title="⬆️  Upgrade [NOT COMPLETE]",
                description="Upgrade OpenProject to newer version (BACKLOG)",
                disabled=True
            ),
            MenuChoice(
                value="restore",
                title="🔄 Restore [NOT COMPLETE]",
                description="Restore from backup (BACKLOG)",
                disabled=True
            ),
            MenuChoice(
                value="health",
                title="🏥 Health Check [NOT COMPLETE]",
                description="Verify system health and configuration (BACKLOG)",
                disabled=True
            ),
            MenuChoice(
                value="status",
                title="📊 Status",
                description="View deployment status dashboard"
            ),
            MenuChoice(
                value="maintenance",
                title="🔧 Maintenance [NOT COMPLETE]",
                description="Additional maintenance tools (BACKLOG)",
                disabled=True
            ),
            MenuChoice(
                value="file_server",
                title="📁 File Server [NOT COMPLETE]",
                description="Install and configure file server (BACKLOG)",
                disabled=True
            ),
            MenuChoice(
                value="gitea",
                title="🔧 Gitea [NOT COMPLETE]",
                description="Install Gitea Git hosting server (BACKLOG)",
                disabled=True
            ),
            MenuChoice(
                value="exit",
                title="❌ Exit",
                description="Exit OpenProject orchestrator"
            ),
        ]
        
        return self.menu.select(
            choices=choices,
            message="What would you like to do?",
            title="OpenProject Deployment Orchestrator v2.0.0"
        )
```

---

### 2. Config-Manager Coordinator

**Location**: `src/openproject_orchestrator/coordinators/config_coordinator.py`

**Purpose**: Wrapper around config-manager package that adapts it for OpenProject TUI

**Responsibilities**:
- Import and initialize config-manager
- Translate config-manager outputs to main orchestrator format
- Collect generated configuration files
- Provide configuration status to TUI

**Implementation**:
```python
from pathlib import Path
from typing import Dict, Any, Optional
from dataclasses import dataclass
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn

# Import packaged config-manager
from openproject_config_manager import ConfigurationManager
from openproject_config_manager.core import ConfigResult

@dataclass
class ConfigState:
    """Configuration state for orchestrator"""
    is_configured: bool = False
    config_file: Optional[Path] = None
    env_file: Optional[Path] = None
    configuration: Optional[Dict[str, Any]] = None
    validation_passed: bool = False
    

class ConfigCoordinator:
    """Coordinates config-manager submodule"""
    
    def __init__(self):
        self.console = Console()
        self.config_mgr = None
        self.state = ConfigState()
        
    def run_interactive_configuration(
        self,
        template: str = "openproject",
        prober_enabled: bool = True,
        output_dir: Path = Path("./config")
    ) -> ConfigResult:
        """
        Run interactive configuration using config-manager
        
        This delegates to the config-manager package which handles:
        - Phase 1: Discovery (auto-detect environment)
        - Phase 2: TUI Mapping (prepare for interactive collection)
        - Phase 3: Collection (user input via TUI)
        - Phase 4: Validation (verify configuration)
        - Phase 5: Export (generate .env, .cfg files)
        """
        self.console.print("\n[cyan]Starting Interactive Configuration...[/cyan]\n")
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=self.console
        ) as progress:
            task = progress.add_task("Initializing configuration system...", total=None)
            
            # Initialize config-manager
            self.config_mgr = ConfigurationManager(
                template=template,
                output_dir=output_dir
            )
            
            progress.update(task, description="Running configuration workflow...")
            
            # Run the 5-phase workflow
            result = self.config_mgr.run_interactive(
                prober_enabled=prober_enabled,
                resume=False  # Start fresh
            )
            
            if result.success:
                self.state.is_configured = True
                self.state.config_file = result.config_file
                self.state.env_file = result.env_file
                self.state.configuration = result.configuration
                self.state.validation_passed = True
                
                progress.update(task, description="✅ Configuration complete!", completed=True)
                self.console.print(f"\n[green]✓[/green] Configuration saved:")
                self.console.print(f"  • Config: {result.config_file}")
                self.console.print(f"  • Env:    {result.env_file}")
            else:
                progress.update(task, description="❌ Configuration failed", completed=True)
                self.console.print(f"\n[red]✗[/red] Configuration failed: {result.error}")
                
        return result
    
    def load_existing_configuration(self, config_file: Path) -> bool:
        """Load existing configuration file"""
        if not config_file.exists():
            self.console.print(f"[red]✗[/red] Configuration file not found: {config_file}")
            return False
            
        self.config_mgr = ConfigurationManager()
        result = self.config_mgr.load_config(config_file)
        
        if result.success:
            self.state.is_configured = True
            self.state.config_file = config_file
            self.state.configuration = result.configuration
            self.console.print(f"[green]✓[/green] Loaded configuration from {config_file}")
            return True
        else:
            self.console.print(f"[red]✗[/red] Failed to load configuration: {result.error}")
            return False
    
    def get_configuration(self) -> Optional[Dict[str, Any]]:
        """Get current configuration"""
        return self.state.configuration
    
    def is_configured(self) -> bool:
        """Check if system is configured"""
        return self.state.is_configured
```

---

### 3. Deploy-Manager Coordinator

**Location**: `src/openproject_orchestrator/coordinators/deploy_coordinator.py`

**Purpose**: Wrapper around deploy-manager package for deployment orchestration

**Responsibilities**:
- Import and initialize deploy-manager
- Feed configuration from config-manager
- Provide OpenProject-specific templates
- Monitor deployment progress
- Report deployment status to TUI

**Implementation**:
```python
from pathlib import Path
from typing import Dict, Any, Optional, List
from dataclasses import dataclass
from enum import Enum
from rich.console import Console
from rich.progress import Progress, BarColumn, TaskProgressColumn

# Import packaged deploy-manager
from openproject_deploy_manager import DeploymentOrchestrator
from openproject_deploy_manager.core import DeploymentResult, DeploymentStatus

class DeploymentPhase(Enum):
    """Deployment phases"""
    PREFLIGHT = "preflight"
    TEMPLATE_RENDERING = "template_rendering"
    SNAPSHOT = "snapshot"
    DEPLOYMENT = "deployment"
    HEALTH_VERIFICATION = "health_verification"
    

@dataclass
class DeployState:
    """Deployment state"""
    is_deployed: bool = False
    current_phase: Optional[DeploymentPhase] = None
    deployment_result: Optional[DeploymentResult] = None
    services_running: List[str] = None
    

class DeployCoordinator:
    """Coordinates deploy-manager submodule"""
    
    def __init__(self, config_coordinator):
        self.console = Console()
        self.config_coordinator = config_coordinator
        self.deployer = None
        self.state = DeployState()
        
    def deploy(
        self,
        dry_run: bool = False,
        prober_enabled: bool = True,
        templates_dir: Path = Path("./templates"),
        compose_file: Path = Path("./docker-compose.yml")
    ) -> DeploymentResult:
        """
        Deploy OpenProject using deploy-manager
        
        This delegates to deploy-manager which handles:
        - Phase 1: Preflight checks (Docker, config, resources)
        - Phase 2: Template rendering (Caddyfile, compose overrides)
        - Phase 3: Snapshot (backup current state)
        - Phase 4: Deployment (docker-compose up)
        - Phase 5: Health verification (prober checks)
        """
        # Ensure we have configuration
        if not self.config_coordinator.is_configured():
            self.console.print("[red]✗[/red] No configuration found. Run configuration first.")
            return DeploymentResult(success=False, error="No configuration")
        
        config = self.config_coordinator.get_configuration()
        
        self.console.print("\n[cyan]Starting Deployment...[/cyan]\n")
        
        with Progress(console=self.console) as progress:
            # Create tasks for each phase
            task_overall = progress.add_task("[cyan]Overall Progress", total=5)
            task_current = progress.add_task("[green]Current Phase", total=100)
            
            # Initialize deployer
            self.deployer = DeploymentOrchestrator(
                config=config,
                templates_dir=templates_dir,
                compose_file=compose_file
            )
            
            # Phase 1: Preflight
            self.state.current_phase = DeploymentPhase.PREFLIGHT
            progress.update(task_current, description="[yellow]Preflight checks...")
            result = self.deployer.run_preflight_checks()
            if not result.success:
                return self._handle_deployment_failure(result)
            progress.update(task_overall, advance=1)
            
            # Phase 2: Template Rendering
            self.state.current_phase = DeploymentPhase.TEMPLATE_RENDERING
            progress.update(task_current, description="[yellow]Rendering templates...")
            result = self.deployer.render_templates()
            if not result.success:
                return self._handle_deployment_failure(result)
            progress.update(task_overall, advance=1)
            
            # Phase 3: Snapshot (if not dry run)
            if not dry_run:
                self.state.current_phase = DeploymentPhase.SNAPSHOT
                progress.update(task_current, description="[yellow]Creating snapshot...")
                result = self.deployer.create_snapshot()
                progress.update(task_overall, advance=1)
            
            # Phase 4: Deployment
            if not dry_run:
                self.state.current_phase = DeploymentPhase.DEPLOYMENT
                progress.update(task_current, description="[yellow]Deploying services...")
                result = self.deployer.deploy(
                    pull_images=True,
                    recreate=False
                )
                if not result.success:
                    return self._handle_deployment_failure(result)
                progress.update(task_overall, advance=1)
            
            # Phase 5: Health Verification
            if not dry_run and prober_enabled:
                self.state.current_phase = DeploymentPhase.HEALTH_VERIFICATION
                progress.update(task_current, description="[yellow]Verifying health...")
                result = self.deployer.verify_health(timeout=300)
                if not result.success:
                    self.console.print("[yellow]⚠[/yellow] Health check warnings (non-fatal)")
                progress.update(task_overall, advance=1)
            
            progress.update(task_current, description="[green]✅ Deployment complete!")
            
        if dry_run:
            self.console.print("\n[green]✓[/green] Dry run successful - no changes made")
        else:
            self.state.is_deployed = True
            self.state.deployment_result = result
            self.console.print("\n[green]✓[/green] Deployment successful!")
            self.console.print(f"\nOpenProject is now running at:")
            self.console.print(f"  🌐 {config.get('OPENPROJECT_HOST__NAME', 'localhost:8080')}")
            
        return result
    
    def _handle_deployment_failure(self, result: DeploymentResult) -> DeploymentResult:
        """Handle deployment failure"""
        self.console.print(f"\n[red]✗[/red] Deployment failed: {result.error}")
        
        # Ask user if they want to rollback
        if self.deployer.has_snapshot():
            should_rollback = self.menu.confirm(
                "Rollback to previous state?",
                default=True
            )
            if should_rollback:
                self.console.print("\n[yellow]Rolling back...[/yellow]")
                rollback_result = self.deployer.rollback()
                if rollback_result.success:
                    self.console.print("[green]✓[/green] Rollback successful")
                else:
                    self.console.print(f"[red]✗[/red] Rollback failed: {rollback_result.error}")
        
        return result
    
    def get_status(self) -> DeploymentStatus:
        """Get deployment status"""
        if not self.deployer:
            return DeploymentStatus(deployed=False)
        return self.deployer.get_status()
```

---

### 4. Maintenance Manager

**Location**: `src/openproject_orchestrator/maintenance/maintenance_manager.py`

**Purpose**: OpenProject-specific maintenance operations (backup, upgrade, restore)

**Responsibilities**:
- Backup OpenProject data (PostgreSQL, attachments)
- Upgrade OpenProject version
- Restore from backup
- Manage backup history
- Database migrations

**Implementation**:
```python
from pathlib import Path
from datetime import datetime
from typing import List, Optional
from dataclasses import dataclass
from rich.console import Console
from rich.table import Table

@dataclass
class BackupInfo:
    """Backup metadata"""
    timestamp: datetime
    backup_path: Path
    version: str
    size_mb: float
    database_backup: Path
    attachments_backup: Path
    config_backup: Path
    

class MaintenanceManager:
    """OpenProject-specific maintenance operations"""
    
    def __init__(self):
        self.console = Console()
        self.backup_dir = Path("./backups")
        self.backup_dir.mkdir(exist_ok=True)
        
    def backup(
        self,
        include_database: bool = True,
        include_attachments: bool = True,
        include_config: bool = True,
        description: Optional[str] = None
    ) -> BackupInfo:
        """
        Create backup of OpenProject data
        
        Steps:
        1. Stop OpenProject services (optional)
        2. Backup PostgreSQL database (pg_dump)
        3. Backup attachments directory
        4. Backup configuration files
        5. Create metadata file
        6. Restart services
        """
        timestamp = datetime.now()
        backup_name = f"openproject_backup_{timestamp.strftime('%Y%m%d_%H%M%S')}"
        backup_path = self.backup_dir / backup_name
        backup_path.mkdir()
        
        self.console.print(f"\n[cyan]Creating backup: {backup_name}[/cyan]\n")
        
        with Progress(console=self.console) as progress:
            task = progress.add_task("Backing up...", total=3)
            
            # Backup database
            if include_database:
                progress.update(task, description="Backing up database...")
                db_backup = self._backup_database(backup_path)
                progress.advance(task)
            
            # Backup attachments
            if include_attachments:
                progress.update(task, description="Backing up attachments...")
                attachments_backup = self._backup_attachments(backup_path)
                progress.advance(task)
            
            # Backup config
            if include_config:
                progress.update(task, description="Backing up configuration...")
                config_backup = self._backup_config(backup_path)
                progress.advance(task)
        
        # Create metadata
        metadata = self._create_backup_metadata(
            backup_path=backup_path,
            timestamp=timestamp,
            description=description
        )
        
        self.console.print(f"\n[green]✓[/green] Backup created: {backup_path}")
        return metadata
    
    def restore(self, backup_info: BackupInfo) -> bool:
        """Restore from backup"""
        self.console.print(f"\n[cyan]Restoring from backup: {backup_info.backup_path}[/cyan]\n")
        
        # Confirm with user
        self.console.print(f"[yellow]⚠[/yellow] This will restore OpenProject to:")
        self.console.print(f"  • Timestamp: {backup_info.timestamp}")
        self.console.print(f"  • Version: {backup_info.version}")
        
        confirm = self.menu.confirm("Proceed with restore?", default=False)
        if not confirm:
            self.console.print("[yellow]Restore cancelled[/yellow]")
            return False
        
        with Progress(console=self.console) as progress:
            task = progress.add_task("Restoring...", total=4)
            
            # Stop services
            progress.update(task, description="Stopping services...")
            self._stop_services()
            progress.advance(task)
            
            # Restore database
            progress.update(task, description="Restoring database...")
            self._restore_database(backup_info.database_backup)
            progress.advance(task)
            
            # Restore attachments
            progress.update(task, description="Restoring attachments...")
            self._restore_attachments(backup_info.attachments_backup)
            progress.advance(task)
            
            # Restart services
            progress.update(task, description="Starting services...")
            self._start_services()
            progress.advance(task)
        
        self.console.print(f"\n[green]✓[/green] Restore complete!")
        return True
    
    def upgrade(
        self,
        target_version: str,
        backup_first: bool = True
    ) -> bool:
        """
        Upgrade OpenProject to new version
        
        Steps:
        1. Create backup (optional but recommended)
        2. Pull new Docker image
        3. Stop current services
        4. Update docker-compose.yml
        5. Start services with new version
        6. Run database migrations
        7. Verify health
        """
        self.console.print(f"\n[cyan]Upgrading OpenProject to version {target_version}[/cyan]\n")
        
        # Create backup first
        if backup_first:
            self.console.print("[yellow]Creating pre-upgrade backup...[/yellow]")
            backup = self.backup(description=f"Pre-upgrade backup before {target_version}")
        
        with Progress(console=self.console) as progress:
            task = progress.add_task("Upgrading...", total=6)
            
            # Pull new image
            progress.update(task, description=f"Pulling image {target_version}...")
            self._pull_image(f"openproject/openproject:{target_version}")
            progress.advance(task)
            
            # Update compose file
            progress.update(task, description="Updating docker-compose.yml...")
            self._update_compose_version(target_version)
            progress.advance(task)
            
            # Stop services
            progress.update(task, description="Stopping services...")
            self._stop_services()
            progress.advance(task)
            
            # Start with new version
            progress.update(task, description="Starting upgraded services...")
            self._start_services()
            progress.advance(task)
            
            # Run migrations
            progress.update(task, description="Running database migrations...")
            self._run_migrations()
            progress.advance(task)
            
            # Verify
            progress.update(task, description="Verifying deployment...")
            health_ok = self._verify_health()
            progress.advance(task)
        
        if health_ok:
            self.console.print(f"\n[green]✓[/green] Upgrade to {target_version} successful!")
            return True
        else:
            self.console.print(f"\n[red]✗[/red] Upgrade verification failed")
            
            # Offer rollback
            if backup_first:
                should_rollback = self.menu.confirm(
                    "Rollback to previous version?",
                    default=True
                )
                if should_rollback:
                    return self.restore(backup)
            return False
    
    def list_backups(self) -> List[BackupInfo]:
        """List all available backups"""
        backups = []
        for backup_dir in sorted(self.backup_dir.iterdir(), reverse=True):
            if backup_dir.is_dir():
                metadata = self._load_backup_metadata(backup_dir)
                if metadata:
                    backups.append(metadata)
        return backups
    
    def show_backup_table(self):
        """Display backups in a table"""
        backups = self.list_backups()
        
        table = Table(title="Available Backups")
        table.add_column("Timestamp", style="cyan")
        table.add_column("Version", style="green")
        table.add_column("Size", style="yellow")
        table.add_column("Path", style="blue")
        
        for backup in backups:
            table.add_row(
                backup.timestamp.strftime("%Y-%m-%d %H:%M:%S"),
                backup.version,
                f"{backup.size_mb:.2f} MB",
                str(backup.backup_path.name)
            )
        
        self.console.print(table)
```

---

### 5. Workflow Implementations

**Location**: `src/openproject_orchestrator/workflows/`

#### Quick Deploy Workflow

**File**: `workflows/quick_deploy.py`

```python
def workflow_quick_deploy(self):
    """
    Complete workflow: Configure → Deploy → Verify
    
    This is the recommended path for new deployments
    """
    self.console.print(Panel.fit(
        "[bold cyan]Quick Deploy Workflow[/bold cyan]\n\n"
        "This will guide you through:\n"
        "  1. System discovery and configuration\n"
        "  2. Configuration validation\n"
        "  3. OpenProject deployment\n"
        "  4. Health verification\n\n"
        "[yellow]Estimated time: 5-10 minutes[/yellow]",
        title="🚀 Quick Deploy"
    ))
    
    proceed = self.menu.confirm("Continue with Quick Deploy?", default=True)
    if not proceed:
        return
    
    # Step 1: Configuration
    self.console.print("\n[bold]Step 1/3: Configuration[/bold]")
    config_result = self.config_coordinator.run_interactive_configuration(
        template="openproject",
        prober_enabled=True
    )
    
    if not config_result.success:
        self.console.print("[red]✗[/red] Configuration failed. Aborting deployment.")
        return
    
    # Step 2: Deployment
    self.console.print("\n[bold]Step 2/3: Deployment[/bold]")
    deploy_result = self.deploy_coordinator.deploy(
        dry_run=False,
        prober_enabled=True
    )
    
    if not deploy_result.success:
        self.console.print("[red]✗[/red] Deployment failed.")
        return
    
    # Step 3: Success summary
    self.console.print("\n[bold]Step 3/3: Deployment Complete! [/bold]")
    self._show_deployment_success_summary(config_result, deploy_result)
```

#### Status Dashboard

**File**: `workflows/status_dashboard.py`

```python
def show_status_dashboard(self):
    """
    Display comprehensive status dashboard
    
    Shows:
    - Configuration status
    - Deployment status
    - Service health
    - Resource usage
    - Recent logs
    """
    # Get status from coordinators
    config_status = self.config_coordinator.state
    deploy_status = self.deploy_coordinator.get_status()
    
    # Create dashboard layout
    layout = Layout()
    layout.split_column(
        Layout(name="header", size=3),
        Layout(name="body"),
        Layout(name="footer", size=3)
    )
    
    # Header
    layout["header"].update(Panel(
        "[bold cyan]OpenProject Status Dashboard[/bold cyan]",
        style="cyan"
    ))
    
    # Body with grid
    layout["body"].split_row(
        Layout(name="left"),
        Layout(name="right")
    )
    
    # Configuration status
    config_table = Table(title="Configuration")
    config_table.add_column("Property", style="cyan")
    config_table.add_column("Value", style="green")
    
    config_table.add_row(
        "Status",
        "✅ Configured" if config_status.is_configured else "❌ Not configured"
    )
    if config_status.config_file:
        config_table.add_row("Config File", str(config_status.config_file))
    if config_status.validation_passed:
        config_table.add_row("Validation", "✅ Passed")
    
    layout["left"].update(config_table)
    
    # Deployment status
    deploy_table = Table(title="Deployment")
    deploy_table.add_column("Service", style="cyan")
    deploy_table.add_column("Status", style="green")
    
    if deploy_status.deployed:
        for service in deploy_status.services:
            status_icon = "✅" if service.healthy else "⚠️"
            deploy_table.add_row(service.name, f"{status_icon} {service.status}")
    else:
        deploy_table.add_row("Status", "❌ Not deployed")
    
    layout["right"].update(deploy_table)
    
    # Footer
    layout["footer"].update(Panel(
        "Press [bold]R[/bold] to refresh • [bold]Q[/bold] to quit",
        style="dim"
    ))
    
    self.console.print(layout)
```

---

## Directory Structure

### Proposed Main Project Structure

```
openproject-docker-compose/
├── pyproject.toml                    # Package config with submodule deps
├── README.md                         # Main documentation
├── LICENSE
│
├── src/
│   └── openproject_orchestrator/     # Main orchestrator package
│       ├── __init__.py
│       ├── tui_controller.py         # Main TUI controller
│       ├── cli.py                    # CLI entry point
│       │
│       ├── coordinators/             # Submodule coordinators
│       │   ├── __init__.py
│       │   ├── config_coordinator.py
│       │   └── deploy_coordinator.py
│       │
│       ├── workflows/                # Workflow implementations
│       │   ├── __init__.py
│       │   ├── quick_deploy.py
│       │   ├── status_dashboard.py
│       │   ├── configure.py
│       │   ├── deploy.py
│       │   └── health_check.py
│       │
│       ├── maintenance/              # OpenProject-specific maintenance
│       │   ├── __init__.py
│       │   ├── maintenance_manager.py
│       │   ├── backup.py
│       │   ├── restore.py
│       │   └── upgrade.py
│       │
│       └── utils/                    # Utilities
│           ├── __init__.py
│           ├── docker_utils.py
│           ├── file_utils.py
│           └── logging_utils.py
│
├── templates/                        # OpenProject-specific templates
│   ├── Caddyfile.j2
│   ├── nginx.conf.j2
│   └── docker-compose.override.yml.j2
│
├── config/                           # Generated configs (gitignored)
│   ├── .env
│   ├── interactive_config.cfg
│   └── defaults.yml
│
├── backups/                          # Backup storage (gitignored)
│   └── openproject_backup_YYYYMMDD_HHMMSS/
│
├── docs/                             # Documentation
│   ├── README.md
│   ├── MAIN_PROJECT_TUI_PROPOSAL.md  # This document
│   ├── architecture/
│   ├── guides/
│   └── project/
│
├── tests/                            # Tests
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
└── external/                         # Git submodules (dev only)
    ├── config-manager/
    ├── deploy-manager/
    ├── tui-form-designer/
    ├── control-flow/
    ├── prober/
    └── dependency-manager/
```

---

## CLI Interface

### Entry Point

**File**: `src/openproject_orchestrator/cli.py`

```python
import click
from rich.console import Console
from openproject_orchestrator.tui_controller import TUIController

console = Console()

@click.group()
@click.version_option(version="2.0.0")
def main():
    """OpenProject Deployment Orchestrator"""
    pass

@main.command()
def deploy():
    """
    Launch interactive TUI for deployment
    
    This is the main entry point for the interactive system.
    """
    controller = TUIController()
    controller.run()

@main.command()
@click.option('--template', default='openproject', help='Configuration template')
@click.option('--prober/--no-prober', default=True, help='Enable prober validation')
def configure(template, prober):
    """Run configuration only (non-interactive mode)"""
    controller = TUIController()
    controller.config_coordinator.run_interactive_configuration(
        template=template,
        prober_enabled=prober
    )

@main.command()
@click.option('--dry-run', is_flag=True, help='Simulate deployment without changes')
def deploy_only(dry_run):
    """Deploy with existing configuration"""
    controller = TUIController()
    
    # Check for existing config
    if not controller.config_coordinator.is_configured():
        config_file = Path("./config/interactive_config.cfg")
        if config_file.exists():
            controller.config_coordinator.load_existing_configuration(config_file)
        else:
            console.print("[red]No configuration found. Run 'openproject configure' first.[/red]")
            return
    
    controller.deploy_coordinator.deploy(dry_run=dry_run)

@main.command()
@click.option('--database/--no-database', default=True)
@click.option('--attachments/--no-attachments', default=True)
@click.option('--config/--no-config', default=True)
def backup(database, attachments, config):
    """Create backup of OpenProject data"""
    controller = TUIController()
    controller.maintenance.backup(
        include_database=database,
        include_attachments=attachments,
        include_config=config
    )

@main.command()
@click.argument('backup_name')
def restore(backup_name):
    """Restore from backup"""
    controller = TUIController()
    
    # Find backup
    backups = controller.maintenance.list_backups()
    backup_info = next((b for b in backups if backup_name in str(b.backup_path)), None)
    
    if not backup_info:
        console.print(f"[red]Backup not found: {backup_name}[/red]")
        return
    
    controller.maintenance.restore(backup_info)

@main.command()
@click.argument('version')
@click.option('--backup/--no-backup', default=True, help='Create backup first')
def upgrade(version, backup):
    """Upgrade OpenProject to new version"""
    controller = TUIController()
    controller.maintenance.upgrade(
        target_version=version,
        backup_first=backup
    )

@main.command()
def status():
    """Show deployment status"""
    controller = TUIController()
    controller.show_status_dashboard()

@main.command()
def health():
    """Run health check"""
    controller = TUIController()
    controller.workflow_health_check()

if __name__ == '__main__':
    main()
```

### Usage Examples

```bash
# Interactive TUI (main interface)
openproject deploy

# Quick commands
openproject configure              # Configure only
openproject deploy-only            # Deploy with existing config
openproject deploy-only --dry-run  # Test deployment
openproject backup                 # Create backup
openproject restore backup_20251016_123456
openproject upgrade 14.0.0         # Upgrade version
openproject status                 # Show status
openproject health                 # Health check
```

---

## Integration with Submodules

### Production Dependencies

**pyproject.toml**:

```toml
[project]
name = "openproject-deploy"
version = "2.0.0"
description = "Interactive deployment orchestrator for OpenProject"
authors = [{name = "Justin Bates", email = "your.email@example.com"}]
readme = "README.md"
requires-python = ">=3.8"
license = {text = "MIT"}

dependencies = [
    # UI Framework
    "rich>=13.0.0",
    "click>=8.0.0",
    
    # Core utilities
    "pyyaml>=6.0",
    "docker>=7.0.0",
    "jinja2>=3.0.0",
    "python-dotenv>=1.0.0",
    
    # Packaged submodules (production)
    # These will be installed from PyPI after packaging
    "openproject-config-manager>=2.0.0",
    "openproject-deploy-manager>=2.0.0",
    "openproject-tui-form-designer>=1.0.0",
    "openproject-control-flow>=2.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "pytest-cov>=4.0.0",
    "black>=23.0.0",
    "flake8>=6.0.0",
    "mypy>=1.0.0",
]

[project.scripts]
openproject = "openproject_orchestrator.cli:main"

[build-system]
requires = ["setuptools>=68.0.0", "wheel"]
build-backend = "setuptools.build_meta"
```

### Development vs Production

**Development** (current state):
```python
# Use local submodules
import sys
sys.path.insert(0, './external/config-manager/src')
sys.path.insert(0, './external/deploy-manager/src')

from openproject_config_manager import ConfigurationManager
from openproject_deploy_manager import DeploymentOrchestrator
```

**Production** (after packaging):
```python
# Import from installed packages
from openproject_config_manager import ConfigurationManager
from openproject_deploy_manager import DeploymentOrchestrator
```

**Compatibility Layer** (`src/openproject_orchestrator/compat.py`):
```python
"""
Compatibility layer for dev vs production imports
"""
import sys
from pathlib import Path

def setup_dev_imports():
    """Setup imports for development with local submodules"""
    project_root = Path(__file__).parent.parent.parent
    
    submodules = [
        'config-manager',
        'deploy-manager',
        'tui-form-designer',
        'control-flow',
    ]
    
    for submodule in submodules:
        submodule_src = project_root / 'external' / submodule / 'src'
        if submodule_src.exists():
            sys.path.insert(0, str(submodule_src))

# Auto-detect development environment
if Path('./external/config-manager').exists():
    setup_dev_imports()
```

---

## Implementation Phases

### Phase 1: Core Structure (Week 1)

**Goal**: Basic TUI with menu system

**Tasks**:
- ✅ Create directory structure
- ✅ Implement TUIController with main menu
- ✅ Setup CLI entry point (`openproject deploy`)
- ✅ Create compatibility layer for dev/prod imports
- ✅ Implement basic navigation (menu → exit)

**Deliverables**:
- Working TUI that launches and shows menu
- CLI command `openproject deploy` works
- Can navigate menu (even if options do nothing yet)

### Phase 2: Config Coordinator (Week 2)

**Goal**: Integrate config-manager

**Tasks**:
- ✅ Implement ConfigCoordinator class
- ✅ Test import of config-manager package
- ✅ Wire up "Configure" menu option
- ✅ Handle config-manager outputs
- ✅ Display configuration results in TUI

**Deliverables**:
- "Configure" option runs config-manager
- Configuration files generated
- ConfigCoordinator tracks state

### Phase 3: Deploy Coordinator (Week 3)

**Goal**: Integrate deploy-manager

**Tasks**:
- ✅ Implement DeployCoordinator class
- ✅ Test import of deploy-manager package
- ✅ Wire up "Deploy" menu option
- ✅ Feed config-manager output to deploy-manager
- ✅ Display deployment progress in TUI

**Deliverables**:
- "Deploy" option runs deploy-manager
- Deployment progress shown
- Services started successfully

### Phase 4: Quick Deploy Workflow (Week 4)

**Goal**: End-to-end workflow

**Tasks**:
- ✅ Implement quick_deploy workflow
- ✅ Chain config → deploy → verify
- ✅ Add error handling
- ✅ Add rollback on failure
- ✅ Display success summary

**Deliverables**:
- "Quick Deploy" option works end-to-end
- Handles errors gracefully
- Shows deployment summary

### Phase 5: Maintenance Manager (Week 5) - **BACKLOG**

**Goal**: Backup/restore/upgrade

**Status**: ⏸️ **DEFERRED TO FUTURE PHASE**

**Tasks**:
- ⏳ Implement MaintenanceManager class
- ⏳ Add backup functionality
- ⏳ Add restore functionality
- ⏳ Add upgrade functionality
- ⏳ Wire up maintenance menu options

**Deliverables**:
- Backup/restore/upgrade workflows work
- Backup list and selection
- Pre-upgrade backups automatic

**Note**: Maintenance features are intentionally backlogged. Focus is on core deployment workflow first.

### Phase 6: Status Dashboard (Week 6) - **PARTIAL**

**Goal**: Live status monitoring

**Status**: 🟡 **PARTIAL - Health checks backlogged**

**Tasks**:
- ✅ Implement status dashboard
- ✅ Query deployment status
- ⏳ Show service health (BACKLOG)
- ⏳ Add auto-refresh (BACKLOG)
- ⏳ Display logs (BACKLOG)

**Deliverables** (Minimum):
- Status dashboard shows deployment state
- Configuration status visible
- Basic deployment information

**Backlogged Features**:
- Live service health monitoring
- Auto-refresh functionality
- Log viewing

### Phase 7: Polish & Testing (Week 7-8)

**Goal**: Production ready (Core Features)

**Tasks**:
- ✅ Add comprehensive error handling
- ✅ Add help text and documentation
- ✅ Write integration tests (for core workflows)
- ✅ Add logging
- ✅ Package submodules
- ✅ Update README and guides
- ✅ Beta testing (core deployment workflow)

**Deliverables**:
- Production-ready TUI orchestrator (core features)
- Packaged submodules on PyPI (or private registry)
- Complete documentation
- Tested end-to-end (configure → deploy)

**Backlogged for Future**:
- Maintenance workflows (backup/restore/upgrade)
- Advanced health monitoring
- Log viewing and debugging tools

---

## Benefits & Features

### User Experience Benefits (Core Features)

1. **Single Entry Point**: `openproject deploy` - one command to do everything
2. **Guided Workflows**: Step-by-step guidance for complex operations
3. **Smart Defaults**: Auto-discovery reduces manual configuration
4. **Visual Feedback**: Progress bars, spinners, colored output
5. **Error Recovery**: Automatic rollback on failure *(future)*
6. **No Docker Knowledge Required**: Abstracts Docker complexity

### User Experience Benefits (Backlogged)

1. **Automated Backups**: Regular backups with easy restore *(future)*
2. **Safe Upgrades**: Automatic pre-upgrade backups with rollback *(future)*
3. **Health Monitoring**: Continuous health checks *(future)*
4. **Live Logs**: Real-time log viewing *(future)*

### Technical Benefits

1. **Modular Architecture**: Submodules remain independent and reusable
2. **Clean Separation**: Orchestrator vs implementation
3. **Easy Testing**: Each component tested independently
4. **Package Management**: Standard Python packaging (pip install)
5. **Version Control**: Submodules can version independently
6. **Extensibility**: Easy to add new workflows or maintenance operations

### Operational Benefits (Core Features)

1. **One-Command Deployment**: Complete OpenProject setup in minutes
2. **Centralized Management**: All operations through one interface

### Operational Benefits (Backlogged)

1. **Automated Backups**: Regular backups with easy restore *(future)*
2. **Safe Upgrades**: Automatic pre-upgrade backups with rollback *(future)*
3. **Health Monitoring**: Continuous health checks *(future)*

---

## Success Criteria

### Minimum Viable Product (MVP)

- ✅ TUI launches with main menu
- ✅ Quick Deploy workflow completes successfully
- ✅ Configuration persists between runs
- ✅ Deployment status visible
- ✅ Basic error handling works

### Production Ready (Core Features)

- ✅ Core workflows implemented (configure, deploy, status)
- ✅ Comprehensive error handling
- ⏳ Rollback on failures *(future)*
- ✅ Status dashboard with deployment info
- ✅ Logging and debugging support
- ✅ Documentation complete
- ✅ Integration tests passing (core workflows)
- ✅ Submodules packaged and installable

### Backlogged Features (Future Releases)

- ⏳ Backup workflow
- ⏳ Restore workflow
- ⏳ Upgrade workflow with automatic backups
- ⏳ Health check with live monitoring
- ⏳ Maintenance menu tools
- ⏳ Log viewing interface

### Stretch Goals

- ✅ Multi-instance support (manage multiple OpenProject deployments)
- ✅ Remote deployment (SSH to target server)
- ✅ Scheduled backups
- ✅ Automated upgrade checks
- ✅ Web UI (in addition to TUI)
- ✅ Monitoring and alerting integration

---

## Risk Assessment

### Technical Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Submodule packaging issues | High | Test packaging early, use standard tools |
| Import conflicts in production | Medium | Use compatibility layer, test in clean environment |
| TUI compatibility issues | Medium | Use Universal Menu (already solves VS Code issues) |
| Deployment failures | High | Implement comprehensive rollback, create pre-deploy snapshots |

### Integration Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Config-manager API changes | Medium | Version pins, semantic versioning |
| Deploy-manager not complete | High | Phase implementation, use what exists |
| Control-flow incompatibility | Low | Already integrated and tested |

### Operational Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Data loss during upgrade | High | Mandatory pre-upgrade backups, rollback support |
| Docker daemon unavailable | High | Preflight checks, clear error messages |
| Insufficient disk space | Medium | Check before operations, warn user |

---

## Backlog - Future Features

The following features are intentionally backlogged and will be implemented in future releases:

### Maintenance Manager Module (Future v2.1.0)

**Scope**: Backup, restore, and upgrade workflows

**Components to Implement**:
```
src/openproject_orchestrator/maintenance/
├── __init__.py
├── maintenance_manager.py    # Main maintenance coordinator
├── backup.py                 # Backup operations
├── restore.py                # Restore operations
└── upgrade.py                # Upgrade workflows
```

**Features**:
- **Backup Workflow**:
  - Create snapshots of OpenProject data
  - Store backups with timestamps
  - List available backups
  - Verify backup integrity

- **Restore Workflow**:
  - Select from available backups
  - Restore configuration and data
  - Verify restore success

- **Upgrade Workflow**:
  - Check for new versions
  - Automatic pre-upgrade backup
  - Upgrade OpenProject version
  - Rollback on failure

**Estimated Effort**: 2-3 weeks

### Health Monitoring (Future v2.2.0)

**Scope**: Real-time health checks and monitoring

**Features**:
- Docker container health checks
- Service availability monitoring
- Resource usage monitoring (CPU, memory, disk)
- Database connectivity checks
- Auto-refresh status dashboard
- Alert system for critical issues

**Estimated Effort**: 1-2 weeks

### Log Viewing (Future v2.3.0)

**Scope**: Interactive log viewing and debugging

**Features**:
- View container logs in real-time
- Filter logs by service
- Search logs
- Export logs
- Tail logs with auto-scroll

**Estimated Effort**: 1 week

### File Server Integration (Future v2.4.0)

**Scope**: Deploy and manage file server alongside OpenProject

**Features**:
- **File Server Options**:
  - Nextcloud (full-featured cloud storage)
  - ownCloud (enterprise file sync and share)
  - Seafile (high-performance file sync)
  - FileBrowser (lightweight file manager)
  - MinIO (S3-compatible object storage)

- **Integration Features**:
  - Configure file server from TUI
  - Deploy file server container
  - Link with OpenProject (shared authentication)
  - Configure storage volumes
  - Backup integration
  - SSL/TLS configuration

- **Configuration Options**:
  - Storage location and quotas
  - User authentication method
  - Network configuration
  - Reverse proxy setup
  - External access settings

**Estimated Effort**: 2-3 weeks

**Benefits**:
- Centralized file storage for project documents
- Integration with OpenProject work packages
- Team collaboration on files
- Version control for documents
- Backup and restore capabilities

### Gitea Integration (Future v2.5.0)

**Scope**: Deploy and manage Gitea Git hosting server

**Features**:
- **Gitea Deployment**:
  - Install Gitea container
  - Configure database (SQLite, PostgreSQL, MySQL)
  - Setup SSH access for Git operations
  - Configure web interface

- **Integration Features**:
  - Single Sign-On with OpenProject
  - Link repositories to work packages
  - Webhook integration
  - Issue tracking sync
  - User management sync

- **Configuration Options**:
  - Repository storage location
  - SSH port configuration
  - Web interface port
  - Authentication method (local, LDAP, OAuth)
  - Email notifications
  - LFS (Large File Storage) support

- **Additional Features**:
  - Repository backup and restore
  - Repository migration tools
  - Organization and team management
  - CI/CD integration (Gitea Actions)
  - Package registry

**Estimated Effort**: 2-3 weeks

**Benefits**:
- Self-hosted Git server alongside OpenProject
- Complete project management + code hosting
- Integration between code and project tracking
- No external dependencies (GitHub, GitLab)
- Full control over repositories

### Advanced Features (Future v3.0.0+)

**Potential Future Enhancements**:
- Multi-instance support (manage multiple deployments)
- Remote deployment (SSH to target servers)
- Scheduled backups
- Automated upgrade checks
- Web UI (in addition to TUI)
- Monitoring and alerting integration
- Configuration templates library
- Deployment recipes

---

## Next Steps

### Immediate Actions

1. **Review & Approve Proposal**: Get stakeholder approval
2. **Create Project Board**: Track implementation tasks
3. **Setup Repository Structure**: Create directory structure
4. **Start Phase 1**: Implement core TUI structure

### Development Timeline

```
Week 1:  Core Structure + TUI Framework
Week 2:  Config Coordinator Integration
Week 3:  Deploy Coordinator Integration
Week 4:  Quick Deploy Workflow + Status Dashboard
Week 5-6: Polish, Testing, Documentation

Total: 6 weeks to MVP v2.0.0 (core features)

Future Phases (Backlogged):
- Maintenance Manager (backup/restore/upgrade)
- Advanced Health Monitoring
- Log Viewing Tools
```

### Dependencies

**Before Starting**:
- ✅ Config-manager must be functional
- ✅ Deploy-manager critical units complete
- ✅ Control-flow Interactive UI library available
- ✅ TUI-form-designer accessible

**Can Develop In Parallel**:
- Deploy-manager remaining features
- Documentation updates
- Additional maintenance operations *(backlogged)*

---

## Conclusion

This proposal presents a comprehensive plan for implementing the OpenProject Main Orchestrator as an interactive TUI system that coordinates packaged submodules. The architecture provides:

- **Clean separation** between orchestration and implementation
- **Excellent user experience** through guided workflows
- **Production-ready packaging** with proper dependency management
- **Extensibility** for future enhancements
- **Maintainability** through modular design

**Recommended Action**: Approve proposal and begin Phase 1 implementation.

---

**Document Version**: 1.0  
**Last Updated**: October 16, 2025  
**Author**: System Architect  
**Status**: ✅ Ready for Review
