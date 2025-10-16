"""
Configuration Coordinator

This module provides a coordinator that wraps the config-manager package
and adapts it for use in the main orchestrator.
"""

import sys
from pathlib import Path
from typing import Dict, Any, Optional
from dataclasses import dataclass

from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.panel import Panel


@dataclass
class ConfigState:
    """Configuration state for orchestrator"""
    is_configured: bool = False
    config_file: Optional[Path] = None
    env_file: Optional[Path] = None
    configuration: Optional[Dict[str, Any]] = None
    validation_passed: bool = False


class ConfigCoordinator:
    """
    Coordinates config-manager submodule
    
    This class wraps the config-manager package and provides a clean
    interface for the main orchestrator. It handles:
    - Importing config-manager from submodule (dev) or package (prod)
    - Running interactive configuration
    - Loading existing configuration
    - Tracking configuration state
    """
    
    def __init__(self, workspace_dir: Optional[Path] = None):
        """
        Initialize Config Coordinator
        
        Args:
            workspace_dir: Workspace directory for generated files.
                          Defaults to ./workspace in development mode.
        """
        self.console = Console()
        self.workspace_dir = workspace_dir or Path("./workspace")
        self.config_mgr = None
        self.state = ConfigState()
        
        # Setup imports for development mode
        self._setup_development_imports()
        
    def _setup_development_imports(self):
        """Setup imports for development with local submodules"""
        project_root = Path(__file__).parent.parent.parent.parent
        config_manager_src = project_root / 'external' / 'config-manager' / 'src'
        
        if config_manager_src.exists():
            # Development mode - use local submodule
            if str(config_manager_src) not in sys.path:
                sys.path.insert(0, str(config_manager_src))
            self._dev_mode = True
        else:
            # Production mode - use installed package
            self._dev_mode = False
    
    def run_interactive_configuration(
        self,
        template: str = "openproject",
        prober_enabled: bool = True
    ) -> bool:
        """
        Run interactive configuration using config-manager
        
        This delegates to the config-manager package which handles:
        - Phase 1: Discovery (auto-detect environment)
        - Phase 2: TUI Mapping (prepare for interactive collection)
        - Phase 3: Collection (user input via TUI)
        - Phase 4: Validation (verify configuration)
        - Phase 5: Export (generate .env, .cfg files)
        
        Args:
            template: Template name (default: "openproject")
            prober_enabled: Enable system probing (default: True)
            
        Returns:
            True if configuration succeeded, False otherwise
        """
        try:
            # Import config-manager
            from openproject_config_manager import ConfigurationManager
            
            self.console.print("\n[cyan]Starting Interactive Configuration...[/cyan]\n")
            
            # Ensure workspace directories exist
            output_dir = self.workspace_dir / "config"
            output_dir.mkdir(parents=True, exist_ok=True)
            
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                console=self.console
            ) as progress:
                task = progress.add_task("Initializing configuration system...", total=None)
                
                # Initialize config-manager with workspace paths
                if self._dev_mode:
                    # Development mode: let config-manager auto-detect
                    self.config_mgr = ConfigurationManager(
                        template=template
                    )
                else:
                    # Production mode: provide explicit paths
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
                    
                    progress.update(task, description="✅ Configuration complete!")
                    
                    # Show success message
                    self.console.print()
                    self.console.print(Panel(
                        f"[green]✓[/green] Configuration saved:\n"
                        f"  • Config: [cyan]{result.config_file}[/cyan]\n"
                        f"  • Env:    [cyan]{result.env_file}[/cyan]",
                        title="Configuration Complete",
                        border_style="green"
                    ))
                    
                    return True
                else:
                    progress.update(task, description="❌ Configuration failed")
                    self.console.print(f"\n[red]✗[/red] Configuration failed: {result.error}\n")
                    return False
                    
        except ImportError as e:
            self.console.print(
                f"\n[red]✗[/red] Could not import config-manager: {e}\n"
                f"[dim]Make sure config-manager submodule is initialized or package is installed.[/dim]\n"
            )
            return False
        except Exception as e:
            self.console.print(f"\n[red]✗[/red] Configuration error: {e}\n")
            if self.console.is_terminal:
                import traceback
                self.console.print("[dim]" + traceback.format_exc() + "[/dim]")
            return False
    
    def load_existing_configuration(self, config_file: Path) -> bool:
        """
        Load existing configuration file
        
        Args:
            config_file: Path to configuration file
            
        Returns:
            True if loaded successfully, False otherwise
        """
        if not config_file.exists():
            self.console.print(f"[red]✗[/red] Configuration file not found: {config_file}\n")
            return False
        
        try:
            from openproject_config_manager import ConfigurationManager
            
            self.config_mgr = ConfigurationManager()
            result = self.config_mgr.load_config(config_file)
            
            if result.success:
                self.state.is_configured = True
                self.state.config_file = config_file
                self.state.configuration = result.configuration
                self.console.print(f"[green]✓[/green] Loaded configuration from {config_file}\n")
                return True
            else:
                self.console.print(f"[red]✗[/red] Failed to load configuration: {result.error}\n")
                return False
                
        except ImportError as e:
            self.console.print(
                f"[red]✗[/red] Could not import config-manager: {e}\n"
            )
            return False
        except Exception as e:
            self.console.print(f"[red]✗[/red] Error loading configuration: {e}\n")
            return False
    
    def get_configuration(self) -> Optional[Dict[str, Any]]:
        """
        Get current configuration
        
        Returns:
            Configuration dictionary or None if not configured
        """
        return self.state.configuration
    
    def is_configured(self) -> bool:
        """
        Check if system is configured
        
        Returns:
            True if configured, False otherwise
        """
        return self.state.is_configured
    
    def get_config_file(self) -> Optional[Path]:
        """
        Get configuration file path
        
        Returns:
            Path to config file or None
        """
        return self.state.config_file
    
    def get_env_file(self) -> Optional[Path]:
        """
        Get environment file path
        
        Returns:
            Path to .env file or None
        """
        return self.state.env_file
