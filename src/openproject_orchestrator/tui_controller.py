"""
Main TUI Controller for OpenProject Orchestrator

This module provides the primary interactive terminal user interface.
It displays the main menu and coordinates all workflows.
"""

from typing import Optional
from dataclasses import dataclass
from pathlib import Path

from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.layout import Layout
from rich import box

from openproject_orchestrator.coordinators import ConfigCoordinator, DeployCoordinator
from openproject_orchestrator.utils import get_logger


logger = get_logger(__name__)


@dataclass
class MenuChoice:
    """Represents a menu choice"""

    value: str
    title: str
    description: str
    disabled: bool = False


class TUIController:
    """
    Main TUI Controller

    Manages the interactive terminal interface and coordinates
    all deployment workflows.
    """

    def __init__(self, debug: bool = False):
        """
        Initialize TUI Controller

        Args:
            debug: Enable debug mode
        """
        self.console = Console()
        self.debug = debug

        # Workspace directory for generated files
        self.workspace_dir = Path("./workspace")
        self.workspace_dir.mkdir(exist_ok=True)

        # Coordinators
        logger.debug("Initializing coordinators")
        self.config_coordinator = ConfigCoordinator(workspace_dir=self.workspace_dir)
        self.deploy_coordinator = DeployCoordinator(workspace_dir=self.workspace_dir)
        logger.debug("Coordinators initialized successfully")

    def run(self):
        """Main TUI loop"""
        logger.info("Starting TUI main loop")
        self._show_welcome()

        while True:
            try:
                choice = self._show_main_menu()
                logger.info(f"User selected menu option: {choice}")

                if choice == "quick_deploy":
                    self._workflow_quick_deploy()
                elif choice == "configure":
                    self._workflow_configure()
                elif choice == "deploy":
                    self._workflow_deploy()
                elif choice == "status":
                    self._show_status_dashboard()
                elif choice == "backup":
                    self._show_not_implemented("Backup")
                elif choice == "upgrade":
                    self._show_not_implemented("Upgrade")
                elif choice == "restore":
                    self._show_not_implemented("Restore")
                elif choice == "health":
                    self._show_not_implemented("Health Check")
                elif choice == "maintenance":
                    self._show_not_implemented("Maintenance")
                elif choice == "file_server":
                    self._show_not_implemented("File Server")
                elif choice == "gitea":
                    self._show_not_implemented("Gitea")
                elif choice == "exit":
                    if self._confirm_exit():
                        break
                else:
                    self.console.print(
                        "\n[red]Invalid choice. Please try again.[/red]\n"
                    )
            except ContinueMenu:
                continue

    def _show_welcome(self):
        """Display welcome banner"""
        welcome_text = """
[bold cyan]OpenProject Deployment Orchestrator[/bold cyan]
[dim]Version 2.0.0[/dim]

Interactive deployment and management for OpenProject.
        """
        self.console.print(Panel(welcome_text, box=box.DOUBLE, border_style="cyan"))

    def _show_main_menu(self) -> str:
        """
        Display main menu and get user choice

        Returns:
            Selected menu choice value
        """
        self.console.print()

        # Create menu table
        table = Table(
            show_header=False,
            box=box.ROUNDED,
            border_style="cyan",
            title="[bold]Main Menu[/bold]",
            title_style="bold cyan",
            padding=(0, 2),
        )

        table.add_column("Key", style="bold yellow", width=5)
        table.add_column("Option", style="cyan", width=25)
        table.add_column("Description", style="dim")

        # Core features (implemented)
        table.add_row("1", "🚀 Quick Deploy", "Guided setup and deployment")
        table.add_row("2", "⚙️  Configure", "Interactive configuration")
        table.add_row("3", "📦 Deploy", "Deploy with existing config")

        # Backlogged features (not yet implemented)
        table.add_row(
            "4", "💾 Backup [NOT COMPLETE]", "Backup OpenProject data", style="dim"
        )
        table.add_row(
            "5", "⬆️  Upgrade [NOT COMPLETE]", "Upgrade OpenProject version", style="dim"
        )
        table.add_row(
            "6", "🔄 Restore [NOT COMPLETE]", "Restore from backup", style="dim"
        )
        table.add_row(
            "7", "🏥 Health Check [NOT COMPLETE]", "System health status", style="dim"
        )

        # Core features (implemented)
        table.add_row("8", "📊 Status", "Deployment status dashboard")

        # Backlogged features (not yet implemented)
        table.add_row(
            "9", "🔧 Maintenance [NOT COMPLETE]", "Additional tools", style="dim"
        )
        table.add_row(
            "A", "📁 File Server [NOT COMPLETE]", "Install file server", style="dim"
        )
        table.add_row(
            "B", "🔧 Gitea [NOT COMPLETE]", "Install Gitea (Git hosting)", style="dim"
        )

        # Exit
        table.add_row("0", "❌ Exit", "Exit orchestrator")

        self.console.print(table)
        self.console.print()

        # Get user input
        choice = (
            self.console.input("[bold yellow]Select an option:[/bold yellow] ")
            .strip()
            .lower()
        )

        # Map input to choice value
        choice_map = {
            "1": "quick_deploy",
            "2": "configure",
            "3": "deploy",
            "4": "backup",
            "5": "upgrade",
            "6": "restore",
            "7": "health",
            "8": "status",
            "9": "maintenance",
            "a": "file_server",
            "b": "gitea",
            "0": "exit",
        }

        return choice_map.get(choice, "invalid")

    def _workflow_quick_deploy(self):
        """Quick Deploy workflow - Configure and Deploy in one flow"""
        self.console.print("\n[bold cyan]═══ Quick Deploy Workflow ═══[/bold cyan]")
        self.console.print(
            "[dim]This workflow will guide you through configuration and deployment in one go.[/dim]\n"
        )

        # Step 1: Configuration
        self.console.print("[bold yellow]Step 1: Configuration[/bold yellow]\n")

        # Check if already configured
        if self.config_coordinator.is_configured():
            config_file = self.config_coordinator.get_config_file()
            self.console.print(f"[green]✓[/green] Configuration found: {config_file}")

            use_existing = (
                self.console.input("\nUse existing configuration? (Y/n): ")
                .strip()
                .lower()
            )
            if use_existing in ["n", "no"]:
                self.console.print("\n[cyan]Running configuration workflow...[/cyan]\n")
                success = self.config_coordinator.run_interactive_configuration(
                    template="openproject", prober_enabled=True
                )
                if not success:
                    self.console.print(
                        Panel(
                            "[red]✗ Configuration failed.[/red]\n\n"
                            "Cannot proceed with deployment without configuration.\n"
                            "Please try the 'Configure' option separately.",
                            title="Configuration Error",
                            border_style="red",
                        )
                    )
                    self.console.input("\nPress Enter to continue...")
                    return
            else:
                self.console.print("[green]✓[/green] Using existing configuration\n")
        else:
            self.console.print("[yellow]⚠️  No configuration found.[/yellow]")
            self.console.print("Running configuration workflow...\n")

            success = self.config_coordinator.run_interactive_configuration(
                template="openproject", prober_enabled=True
            )
            if not success:
                self.console.print(
                    Panel(
                        "[red]✗ Configuration failed.[/red]\n\n"
                        "Cannot proceed with deployment without configuration.\n"
                        "Please try the 'Configure' option separately.",
                        title="Configuration Error",
                        border_style="red",
                    )
                )
                self.console.input("\nPress Enter to continue...")
                return

        # Step 2: Deployment
        self.console.print("\n[bold yellow]Step 2: Deployment[/bold yellow]\n")

        # Get configuration
        config = self.config_coordinator.get_configuration()
        if not config:
            self.console.print(
                Panel(
                    "[red]✗ Failed to load configuration.[/red]\n\n"
                    "Please try the 'Configure' option to set up configuration.",
                    title="Configuration Error",
                    border_style="red",
                )
            )
            self.console.input("\nPress Enter to continue...")
            return

        # Display configuration summary
        self.console.print("[dim]Configuration summary:[/dim]")
        self.console.print(f"  Domain: {config.get('domain', 'N/A')}")
        self.console.print(f"  Admin Email: {config.get('admin_email', 'N/A')}")
        self.console.print()

        # Check if already deployed
        if self.deploy_coordinator.is_deployed():
            self.console.print("[yellow]⚠️  Services are already deployed.[/yellow]")
            redeploy = self.console.input("Redeploy anyway? (y/N): ").strip().lower()
            if redeploy not in ["y", "yes"]:
                self.console.print("[dim]Keeping existing deployment.[/dim]\n")
                self.console.input("Press Enter to continue...")
                return

            # Stop existing deployment
            self.console.print("\n[dim]Stopping existing deployment...[/dim]")
            self.deploy_coordinator.stop()
            self.console.print()

        # Prompt for deployment mode
        self.console.print("[cyan]Select deployment mode:[/cyan]")
        self.console.print("  1. Development (local testing)")
        self.console.print("  2. Production (secure, optimized)")
        mode_choice = self.console.input("\nChoice [1]: ").strip() or "1"

        mode = "development" if mode_choice == "1" else "production"

        self.console.print(f"\n[dim]Deploying in {mode} mode...[/dim]\n")

        # Run deployment
        success = self.deploy_coordinator.deploy(configuration=config, mode=mode)

        # Step 3: Verification (if deployment succeeded)
        if success:
            self.console.print("\n[bold yellow]Step 3: Verification[/bold yellow]\n")

            # Get deployment status
            status = self.deploy_coordinator.get_status()

            # Display verification results
            from rich.table import Table

            verify_table = Table(title="Deployment Verification", box=box.ROUNDED)
            verify_table.add_column("Check", style="cyan")
            verify_table.add_column("Status", style="yellow")
            verify_table.add_column("Details", style="dim")

            # Configuration check
            verify_table.add_row(
                "Configuration",
                "[green]✓ Valid[/green]",
                f"{config.get('domain', 'N/A')}",
            )

            # Deployment check
            if status.get("is_deployed"):
                verify_table.add_row(
                    "Deployment",
                    "[green]✓ Deployed[/green]",
                    f"{status.get('services_running', 0)} services running",
                )
            else:
                verify_table.add_row(
                    "Deployment",
                    "[red]✗ Failed[/red]",
                    status.get("error_message", "Unknown error"),
                )

            # Service status (placeholder for now)
            verify_table.add_row(
                "Services",
                "[yellow]⏳ Starting...[/yellow]",
                "Health checks will be available in v2.2.0",
            )

            self.console.print(verify_table)

            self.console.print(
                Panel(
                    "[green]✓ Quick Deploy completed successfully![/green]\n\n"
                    f"Your OpenProject instance is being deployed at:\n"
                    f"[cyan]https://{config.get('domain', 'N/A')}[/cyan]\n\n"
                    f"Services may take a few moments to fully start.\n"
                    f"Use the 'Status' menu to monitor deployment progress.",
                    title="Quick Deploy Complete",
                    border_style="green",
                )
            )
        else:
            self.console.print(
                Panel(
                    "[red]✗ Deployment failed during Quick Deploy.[/red]\n\n"
                    "Please check the error messages above and try again.\n"
                    "You can also use the 'Deploy' option separately for more control.",
                    title="Quick Deploy Failed",
                    border_style="red",
                )
            )

        self.console.input("\nPress Enter to continue...")

    def _workflow_configure(self):
        """Configuration workflow"""
        self.console.print("\n[bold cyan]Configuration Workflow[/bold cyan]")
        self.console.print(
            "[dim]Interactive configuration using config-manager.[/dim]\n"
        )

        # Check if already configured
        if self.config_coordinator.is_configured():
            self.console.print("[yellow]⚠️  System is already configured.[/yellow]\n")
            reconfigure = (
                self.console.input("Do you want to reconfigure? (y/N): ")
                .strip()
                .lower()
            )
            if reconfigure not in ["y", "yes"]:
                self.console.print("[dim]Keeping existing configuration.[/dim]\n")
                self.console.input("Press Enter to continue...")
                return

        # Run interactive configuration
        success = self.config_coordinator.run_interactive_configuration(
            template="openproject", prober_enabled=True
        )

        if success:
            self.console.print("[green]✓[/green] Configuration workflow complete!\n")
        else:
            self.console.print("[red]✗[/red] Configuration failed.\n")

        self.console.input("Press Enter to continue...")

    def _workflow_deploy(self):
        """Deployment workflow"""
        self.console.print("\n[cyan]═══ Deployment Workflow ═══[/cyan]\n")

        # Check if configuration exists
        if not self.config_coordinator.is_configured():
            self.console.print(
                Panel(
                    "[yellow]⚠ No configuration found![/yellow]\n\n"
                    "You must configure OpenProject before deploying.\n"
                    "Please run the 'Configure' option first.",
                    title="Configuration Required",
                    border_style="yellow",
                )
            )
            self.console.input("\nPress Enter to continue...")
            return

        # Display current configuration
        config = self.config_coordinator.get_configuration()
        self.console.print("[dim]Current configuration:[/dim]")
        self.console.print(f"  Domain: {config.get('domain', 'N/A')}")
        self.console.print(f"  Admin Email: {config.get('admin_email', 'N/A')}")
        self.console.print()

        # Check if already deployed
        if self.deploy_coordinator.is_deployed():
            self.console.print("[yellow]⚠ Services are already deployed.[/yellow]")
            response = self.console.input("Redeploy? (yes/no) [no]: ").strip().lower()
            if response != "yes":
                self.console.print("[dim]Keeping existing deployment.[/dim]\n")
                self.console.input("Press Enter to continue...")
                return

            # Stop existing deployment
            self.console.print("\n[dim]Stopping existing deployment...[/dim]")
            self.deploy_coordinator.stop()
            self.console.print()

        # Prompt for deployment mode
        self.console.print("[cyan]Select deployment mode:[/cyan]")
        self.console.print("  1. Development (local testing)")
        self.console.print("  2. Production (secure, optimized)")
        mode_choice = self.console.input("\nChoice [1]: ").strip() or "1"

        mode = "development" if mode_choice == "1" else "production"

        self.console.print(f"\n[dim]Deploying in {mode} mode...[/dim]\n")

        # Run deployment
        success = self.deploy_coordinator.deploy(configuration=config, mode=mode)

        if success:
            self.console.print("\n[green]✓[/green] Deployment workflow complete!\n")
        else:
            self.console.print("\n[red]✗[/red] Deployment failed.\n")

        self.console.input("Press Enter to continue...")

    def _show_status_dashboard(self):
        """Enhanced status dashboard with detailed information"""
        self.console.print("\n[bold cyan]═══ Status Dashboard ═══[/bold cyan]")
        self.console.print(
            "[dim]Comprehensive view of deployment status and system information.[/dim]\n"
        )

        # Main Status Table
        status_table = Table(title="System Status", box=box.ROUNDED, show_header=True)
        status_table.add_column("Component", style="cyan", width=20)
        status_table.add_column("Status", style="yellow", width=25)
        status_table.add_column("Details", style="dim", width=40)

        # Configuration status
        if self.config_coordinator.is_configured():
            config_file = self.config_coordinator.get_config_file()
            config = self.config_coordinator.get_configuration()

            details = []
            if config:
                if config.get("domain"):
                    details.append(f"Domain: {config.get('domain')}")
                if config.get("admin_email"):
                    details.append(f"Email: {config.get('admin_email')}")

            status_table.add_row(
                "Configuration",
                "[green]✓ Configured[/green]",
                "\n".join(details) if details else str(config_file),
            )
        else:
            status_table.add_row(
                "Configuration",
                "[red]❌ Not configured[/red]",
                "Run 'Configure' or 'Quick Deploy'",
            )

        # Deployment status
        if self.deploy_coordinator.is_deployed():
            services_running = self.deploy_coordinator.get_services_running()
            deployment_time = self.deploy_coordinator.get_deployment_time()
            config_used = self.deploy_coordinator.get_configuration_used()

            # Format deployment time
            if deployment_time:
                from datetime import datetime

                try:
                    dt = datetime.fromisoformat(deployment_time)
                    time_str = dt.strftime("%Y-%m-%d %H:%M:%S")
                except:
                    time_str = deployment_time
            else:
                time_str = "Unknown"

            details = [f"Deployed: {time_str}"]
            if config_used and config_used.get("domain"):
                details.append(f"URL: https://{config_used.get('domain')}")

            status_table.add_row(
                "Deployment",
                f"[green]✓ Active ({services_running} services)[/green]",
                "\n".join(details),
            )
        else:
            error = self.deploy_coordinator.get_last_error()
            if error:
                status_table.add_row(
                    "Deployment", "[red]❌ Failed[/red]", f"Error: {error[:50]}..."
                )
            else:
                status_table.add_row(
                    "Deployment",
                    "[yellow]⏸️  Not deployed[/yellow]",
                    "Run 'Deploy' or 'Quick Deploy'",
                )

        self.console.print(status_table)

        # Configuration Details (if configured)
        if self.config_coordinator.is_configured():
            config = self.config_coordinator.get_configuration()
            if config:
                self.console.print("\n[bold cyan]Configuration Details:[/bold cyan]")

                config_details = Table(
                    box=box.SIMPLE, show_header=False, padding=(0, 2)
                )
                config_details.add_column("Key", style="dim")
                config_details.add_column("Value", style="white")

                # Show key configuration values
                important_keys = [
                    "domain",
                    "admin_email",
                    "smtp_enabled",
                    "ssl_enabled",
                    "backup_enabled",
                ]

                for key in important_keys:
                    if key in config:
                        value = config[key]
                        if isinstance(value, bool):
                            value = "✓ Yes" if value else "✗ No"
                        config_details.add_row(
                            key.replace("_", " ").title(), str(value)
                        )

                self.console.print(config_details)

        # Deployment Details (if deployed)
        if self.deploy_coordinator.is_deployed():
            self.console.print("\n[bold cyan]Deployment Information:[/bold cyan]")

            deploy_details = Table(box=box.SIMPLE, show_header=False, padding=(0, 2))
            deploy_details.add_column("Key", style="dim")
            deploy_details.add_column("Value", style="white")

            status = self.deploy_coordinator.get_status()

            deploy_details.add_row(
                "Services Running", str(status.get("services_running", 0))
            )
            deploy_details.add_row(
                "Deployment Status",
                (
                    "[green]Success[/green]"
                    if status.get("deployment_successful")
                    else "[red]Failed[/red]"
                ),
            )

            if status.get("deployment_time"):
                from datetime import datetime

                try:
                    dt = datetime.fromisoformat(status["deployment_time"])
                    time_str = dt.strftime("%Y-%m-%d %H:%M:%S")
                except:
                    time_str = status["deployment_time"]
                deploy_details.add_row("Last Deployment", time_str)

            self.console.print(deploy_details)

        # Quick Actions
        self.console.print("\n[bold cyan]Quick Actions:[/bold cyan]")
        actions_table = Table(box=box.SIMPLE, show_header=False, padding=(0, 2))
        actions_table.add_column("Action", style="yellow")
        actions_table.add_column("Description", style="dim")

        if not self.config_coordinator.is_configured():
            actions_table.add_row("1. Configure", "Set up OpenProject configuration")

        if not self.deploy_coordinator.is_deployed():
            actions_table.add_row("2. Deploy", "Deploy OpenProject services")

        if (
            self.config_coordinator.is_configured()
            and not self.deploy_coordinator.is_deployed()
        ):
            actions_table.add_row("Quick Deploy", "Configure and deploy in one step")

        if self.deploy_coordinator.is_deployed():
            actions_table.add_row("Redeploy", "Stop and redeploy services")

        self.console.print(actions_table)

        # Future features note
        self.console.print(
            "\n[dim]Note: Live monitoring, health checks, and log viewing will be available in future releases (v2.2+)[/dim]\n"
        )

        self.console.input("Press Enter to continue...")

    def _show_not_implemented(self, feature_name: str):
        """Show message for backlogged features"""
        self.console.print(f"\n[yellow]⚠️  {feature_name}[/yellow]")
        self.console.print(
            f"[dim]This feature is in the backlog and will be implemented in a future release.[/dim]\n"
        )

        # Show relevant version info
        version_map = {
            "Backup": "v2.1.0",
            "Restore": "v2.1.0",
            "Upgrade": "v2.1.0",
            "Maintenance": "v2.1.0",
            "Health Check": "v2.2.0",
            "File Server": "v2.4.0",
            "Gitea": "v2.5.0",
        }

        if feature_name in version_map:
            self.console.print(f"[dim]Planned for: {version_map[feature_name]}[/dim]\n")

        self.console.input("Press Enter to continue...")

    def _confirm_exit(self) -> bool:
        """
        Confirm exit

        Returns:
            True if user confirms exit, False otherwise
        """
        self.console.print()
        confirm = (
            self.console.input(
                "[yellow]Are you sure you want to exit? (y/N):[/yellow] "
            )
            .strip()
            .lower()
        )

        if confirm == "y" or confirm == "yes":
            self.console.print(
                "\n[green]✓[/green] Thank you for using OpenProject Orchestrator!"
            )
            self.console.print("[dim]Goodbye![/dim]\n")
            return True
        else:
            self.console.print("[dim]Continuing...[/dim]")
            return False


class ContinueMenu(Exception):
    """Exception to continue to main menu"""

    pass
