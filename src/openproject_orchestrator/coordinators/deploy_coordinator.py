"""
Deploy Coordinator

Wraps the deploy-manager package to coordinate deployment operations
within the TUI orchestrator. Handles deployment execution, state tracking,
and progress display.

Features:
- Development/Production mode detection
- Deploy with configuration input
- Track deployment state
- Rich progress display
- Error handling and recovery
"""

import sys
from pathlib import Path
from dataclasses import dataclass
from typing import Optional, Dict, Any
from rich.console import Console
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn


@dataclass
class DeploymentState:
    """
    Tracks the current state of deployment operations.
    
    Attributes:
        is_deployed: Whether services are currently deployed
        deployment_time: Timestamp of last deployment
        services_running: Number of services running
        configuration_used: Configuration dict used for deployment
        deployment_successful: Whether last deployment was successful
        error_message: Error message if deployment failed
    """
    is_deployed: bool = False
    deployment_time: Optional[str] = None
    services_running: int = 0
    configuration_used: Optional[Dict[str, Any]] = None
    deployment_successful: bool = False
    error_message: Optional[str] = None


class DeployCoordinator:
    """
    Coordinates deployment operations using the deploy-manager package.
    
    This coordinator wraps deploy-manager v2.0.0 to provide:
    - Deployment execution with configuration
    - State tracking and status reporting
    - Progress display with Rich components
    - Error handling and user feedback
    
    The coordinator automatically detects development vs production mode
    and imports the appropriate deploy-manager package.
    """
    
    def __init__(self, workspace_dir: Path):
        """
        Initialize the Deploy Coordinator.
        
        Args:
            workspace_dir: Path to the workspace directory for deployment files
        """
        self.console = Console()
        self.workspace_dir = workspace_dir
        self.state = DeploymentState()
        
        # Ensure workspace directory exists
        self.workspace_dir.mkdir(parents=True, exist_ok=True)
        
        # Setup development mode imports if needed
        self._setup_development_imports()
        
        # Import deploy-manager components
        try:
            from openproject_deploy_manager import DeploymentOrchestrator
            self.DeploymentOrchestrator = DeploymentOrchestrator
            self._dev_mode = self._is_development_mode()
        except ImportError as e:
            self.console.print(Panel(
                f"[red]Error: Could not import deploy-manager package.[/red]\n\n"
                f"Details: {str(e)}\n\n"
                f"Please ensure deploy-manager is installed:\n"
                f"  pip install openproject-deploy-manager\n\n"
                f"Or in development mode, ensure the external/deploy-manager submodule is initialized.",
                title="Import Error",
                border_style="red"
            ))
            raise
    
    def _setup_development_imports(self):
        """
        Setup development mode imports.
        
        Note: In development mode, submodules should be installed in editable mode:
            pip install -e external/deploy-manager/
        
        In production mode, the package is installed normally:
            pip install openproject-deploy-manager
        
        This avoids runtime sys.path manipulation.
        """
        # No sys.path.insert needed - rely on proper Python packaging
        pass
    
    def _is_development_mode(self) -> bool:
        """
        Check if we're running in development mode.
        
        Returns:
            True if using local submodule, False if using installed package
        """
        current_file = Path(__file__).resolve()
        project_root = current_file.parent.parent.parent.parent
        deploy_manager_dir = project_root / "external" / "deploy-manager"
        
        # Check if .git exists (submodule) and src directory exists
        return (deploy_manager_dir / ".git").exists() and \
               (deploy_manager_dir / "src").exists()
    
    def deploy(
        self,
        configuration: Dict[str, Any],
        mode: str = "development"
    ) -> bool:
        """
        Deploy OpenProject services using the provided configuration.
        
        This method:
        1. Validates the configuration
        2. Creates deployment orchestrator instance
        3. Executes the deployment workflow
        4. Tracks deployment state
        
        Args:
            configuration: Configuration dictionary from ConfigCoordinator
            mode: Deployment mode ("development" or "production")
        
        Returns:
            True if deployment successful, False otherwise
        """
        try:
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                console=self.console
            ) as progress:
                
                # Phase 1: Validate configuration
                task1 = progress.add_task(
                    "[cyan]Validating configuration...",
                    total=None
                )
                
                # Basic validation - check required fields
                required_fields = ["domain", "admin_email"]
                for field in required_fields:
                    if field not in configuration:
                        raise ValueError(f"Missing required configuration field: {field}")
                
                progress.update(task1, completed=True)
                
                # Phase 2: Initialize deployment orchestrator
                task2 = progress.add_task(
                    "[cyan]Initializing deployment orchestrator...",
                    total=None
                )
                
                # Get project root
                current_file = Path(__file__).resolve()
                project_root = current_file.parent.parent.parent.parent
                
                # Setup paths for deployment
                templates_dir = project_root / "templates"
                output_dir = self.workspace_dir / "outputs"
                compose_file = self.workspace_dir / "docker-compose.yml"
                snapshot_dir = self.workspace_dir / "snapshots"
                
                # Create orchestrator
                orchestrator = self.DeploymentOrchestrator(
                    config=configuration,
                    templates_dir=templates_dir,
                    output_dir=output_dir,
                    compose_file=compose_file,
                    snapshot_dir=snapshot_dir,
                    use_local_paths=self._dev_mode
                )
                
                progress.update(task2, completed=True)
                
                # Phase 3: Execute deployment
                task3 = progress.add_task(
                    "[cyan]Executing deployment workflow...",
                    total=None
                )
                
                result = orchestrator.deploy(dry_run=False)
                
                progress.update(task3, completed=True)
                
                # Phase 4: Verify deployment
                task4 = progress.add_task(
                    "[cyan]Verifying deployment...",
                    total=None
                )
                
                # Check if deployment was successful
                if result.get('status') != 'success':
                    raise Exception(result.get('message', 'Deployment failed'))
                
                progress.update(task4, completed=True)
            
            # Update state
            import datetime
            self.state.is_deployed = True
            self.state.deployment_time = datetime.datetime.now().isoformat()
            self.state.services_running = result.get('services_deployed', 0)
            self.state.configuration_used = configuration
            self.state.deployment_successful = True
            self.state.error_message = None
            
            # Display success message
            self.console.print(Panel(
                f"[green]✓ Deployment completed successfully![/green]\n\n"
                f"Services deployed: {self.state.services_running}\n"
                f"Mode: {mode}\n"
                f"Domain: {configuration.get('domain', 'N/A')}\n\n"
                f"Your OpenProject instance is now running!",
                title="Deployment Successful",
                border_style="green"
            ))
            
            return True
            
        except FileNotFoundError as e:
            error_msg = f"Required file not found: {str(e)}"
            self.state.deployment_successful = False
            self.state.error_message = error_msg
            self.console.print(Panel(
                f"[red]✗ Deployment failed[/red]\n\n"
                f"Error: {error_msg}\n\n"
                f"Please ensure all configuration files are present.",
                title="Deployment Error",
                border_style="red"
            ))
            return False
            
        except ValueError as e:
            error_msg = f"Configuration validation failed: {str(e)}"
            self.state.deployment_successful = False
            self.state.error_message = error_msg
            self.console.print(Panel(
                f"[red]✗ Deployment failed[/red]\n\n"
                f"Error: {error_msg}\n\n"
                f"Please check your configuration and try again.",
                title="Deployment Error",
                border_style="red"
            ))
            return False
            
        except Exception as e:
            error_msg = f"Unexpected error: {str(e)}"
            self.state.deployment_successful = False
            self.state.error_message = error_msg
            self.console.print(Panel(
                f"[red]✗ Deployment failed[/red]\n\n"
                f"Error: {error_msg}\n\n"
                f"Please check the logs for more details.",
                title="Deployment Error",
                border_style="red"
            ))
            return False
    
    def get_status(self) -> Dict[str, Any]:
        """
        Get the current deployment status.
        
        Returns:
            Dictionary with deployment status information
        """
        return {
            "is_deployed": self.state.is_deployed,
            "services_running": self.state.services_running,
            "deployment_time": self.state.deployment_time,
            "deployment_successful": self.state.deployment_successful,
            "error_message": self.state.error_message
        }
    
    def stop(self) -> bool:
        """
        Stop all deployed services.
        
        Note: Full stop functionality will be implemented when deploy-manager
        adds a teardown/stop method. For now, this updates state only.
        
        Returns:
            True if services stopped successfully, False otherwise
        """
        try:
            self.console.print("[yellow]Note: Full service teardown will be available in a future version.[/yellow]")
            self.console.print("[dim]Updating deployment state...[/dim]\n")
            
            # Update state
            self.state.is_deployed = False
            self.state.services_running = 0
            
            self.console.print(Panel(
                "[green]✓ Deployment state updated.[/green]\n\n"
                "[dim]To manually stop services, run:[/dim]\n"
                "[cyan]docker-compose down[/cyan]",
                title="State Updated",
                border_style="green"
            ))
            
            return True
            
        except Exception as e:
            self.console.print(Panel(
                f"[red]✗ Failed to update state[/red]\n\n"
                f"Error: {str(e)}",
                title="Update Error",
                border_style="red"
            ))
            return False
    
    # State accessors
    
    def is_deployed(self) -> bool:
        """Check if services are currently deployed."""
        return self.state.is_deployed
    
    def get_deployment_time(self) -> Optional[str]:
        """Get the timestamp of the last deployment."""
        return self.state.deployment_time
    
    def get_services_running(self) -> int:
        """Get the number of services currently running."""
        return self.state.services_running
    
    def get_configuration_used(self) -> Optional[Dict[str, Any]]:
        """Get the configuration used for the current deployment."""
        return self.state.configuration_used
    
    def get_last_error(self) -> Optional[str]:
        """Get the last error message, if any."""
        return self.state.error_message
