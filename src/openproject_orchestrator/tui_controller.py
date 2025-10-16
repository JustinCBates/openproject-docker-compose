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

from openproject_orchestrator.coordinators import ConfigCoordinator


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
        self.config_coordinator = ConfigCoordinator(workspace_dir=self.workspace_dir)
        # self.deploy_coordinator = DeployCoordinator()  # Phase 3
        
    def run(self):
        """Main TUI loop"""
        self._show_welcome()
        
        while True:
            try:
                choice = self._show_main_menu()
                
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
                    self.console.print("\n[red]Invalid choice. Please try again.[/red]\n")
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
            padding=(0, 2)
        )
        
        table.add_column("Key", style="bold yellow", width=5)
        table.add_column("Option", style="cyan", width=25)
        table.add_column("Description", style="dim")
        
        # Core features (implemented)
        table.add_row("1", "🚀 Quick Deploy", "Guided setup and deployment")
        table.add_row("2", "⚙️  Configure", "Interactive configuration")
        table.add_row("3", "📦 Deploy", "Deploy with existing config")
        
        # Backlogged features (not yet implemented)
        table.add_row("4", "💾 Backup [NOT COMPLETE]", "Backup OpenProject data", style="dim")
        table.add_row("5", "⬆️  Upgrade [NOT COMPLETE]", "Upgrade OpenProject version", style="dim")
        table.add_row("6", "🔄 Restore [NOT COMPLETE]", "Restore from backup", style="dim")
        table.add_row("7", "🏥 Health Check [NOT COMPLETE]", "System health status", style="dim")
        
        # Core features (implemented)
        table.add_row("8", "📊 Status", "Deployment status dashboard")
        
        # Backlogged features (not yet implemented)
        table.add_row("9", "🔧 Maintenance [NOT COMPLETE]", "Additional tools", style="dim")
        table.add_row("A", "📁 File Server [NOT COMPLETE]", "Install file server", style="dim")
        table.add_row("B", "🔧 Gitea [NOT COMPLETE]", "Install Gitea (Git hosting)", style="dim")
        
        # Exit
        table.add_row("0", "❌ Exit", "Exit orchestrator")
        
        self.console.print(table)
        self.console.print()
        
        # Get user input
        choice = self.console.input("[bold yellow]Select an option:[/bold yellow] ").strip().lower()
        
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
        """Quick Deploy workflow (to be implemented in Phase 4)"""
        self.console.print("\n[cyan]Quick Deploy Workflow[/cyan]")
        self.console.print("[dim]This workflow will guide you through configuration and deployment.[/dim]\n")
        self.console.print("[yellow]⏳ Not yet implemented - Coming in Phase 4[/yellow]\n")
        self.console.input("Press Enter to continue...")
    
    def _workflow_configure(self):
        """Configuration workflow"""
        self.console.print("\n[bold cyan]Configuration Workflow[/bold cyan]")
        self.console.print("[dim]Interactive configuration using config-manager.[/dim]\n")
        
        # Check if already configured
        if self.config_coordinator.is_configured():
            self.console.print("[yellow]⚠️  System is already configured.[/yellow]\n")
            reconfigure = self.console.input("Do you want to reconfigure? (y/N): ").strip().lower()
            if reconfigure not in ["y", "yes"]:
                self.console.print("[dim]Keeping existing configuration.[/dim]\n")
                self.console.input("Press Enter to continue...")
                return
        
        # Run interactive configuration
        success = self.config_coordinator.run_interactive_configuration(
            template="openproject",
            prober_enabled=True
        )
        
        if success:
            self.console.print("[green]✓[/green] Configuration workflow complete!\n")
        else:
            self.console.print("[red]✗[/red] Configuration failed.\n")
        
        self.console.input("Press Enter to continue...")
    
    def _workflow_deploy(self):
        """Deployment workflow (to be implemented in Phase 3)"""
        self.console.print("\n[cyan]Deployment Workflow[/cyan]")
        self.console.print("[dim]Deploy OpenProject using deploy-manager.[/dim]\n")
        self.console.print("[yellow]⏳ Not yet implemented - Coming in Phase 3[/yellow]\n")
        self.console.input("Press Enter to continue...")
    
    def _show_status_dashboard(self):
        """Status dashboard"""
        self.console.print("\n[bold cyan]Status Dashboard[/bold cyan]")
        self.console.print("[dim]View deployment status and system information.[/dim]\n")
        
        # Configuration status
        status_table = Table(title="Current Status", box=box.SIMPLE)
        status_table.add_column("Component", style="cyan")
        status_table.add_column("Status", style="yellow")
        status_table.add_column("Details", style="dim")
        
        # Configuration status
        if self.config_coordinator.is_configured():
            config_file = self.config_coordinator.get_config_file()
            status_table.add_row(
                "Configuration",
                "[green]✓ Configured[/green]",
                str(config_file) if config_file else ""
            )
        else:
            status_table.add_row(
                "Configuration",
                "[red]❌ Not configured[/red]",
                "Run 'Configure' to set up"
            )
        
        # Deployment status (Phase 3)
        status_table.add_row(
            "Deployment",
            "[dim]❌ Not deployed[/dim]",
            "[dim]Coming in Phase 3[/dim]"
        )
        
        self.console.print(status_table)
        self.console.print("\n[yellow]⏳ Full dashboard with live monitoring coming in Phase 4[/yellow]\n")
        self.console.input("Press Enter to continue...")
    
    def _show_not_implemented(self, feature_name: str):
        """Show message for backlogged features"""
        self.console.print(f"\n[yellow]⚠️  {feature_name}[/yellow]")
        self.console.print(f"[dim]This feature is in the backlog and will be implemented in a future release.[/dim]\n")
        
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
        confirm = self.console.input("[yellow]Are you sure you want to exit? (y/N):[/yellow] ").strip().lower()
        
        if confirm == "y" or confirm == "yes":
            self.console.print("\n[green]✓[/green] Thank you for using OpenProject Orchestrator!")
            self.console.print("[dim]Goodbye![/dim]\n")
            return True
        else:
            self.console.print("[dim]Continuing...[/dim]")
            return False


class ContinueMenu(Exception):
    """Exception to continue to main menu"""
    pass
