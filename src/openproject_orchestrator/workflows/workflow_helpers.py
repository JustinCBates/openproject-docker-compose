"""
Workflow Utilities

Helper functions and classes for TUI workflows.
"""

from typing import Dict, Any, Optional
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich import box


def display_workflow_header(console: Console, title: str, description: str):
    """
    Display a standardized workflow header.
    
    Args:
        console: Rich console instance
        title: Workflow title
        description: Workflow description
    """
    console.print(f"\n[bold cyan]═══ {title} ═══[/bold cyan]")
    console.print(f"[dim]{description}[/dim]\n")


def display_configuration_summary(console: Console, config: Dict[str, Any]):
    """
    Display a formatted configuration summary.
    
    Args:
        console: Rich console instance
        config: Configuration dictionary
    """
    console.print("[dim]Configuration summary:[/dim]")
    
    summary_items = [
        ("Domain", config.get('domain', 'N/A')),
        ("Admin Email", config.get('admin_email', 'N/A')),
        ("SSL Enabled", "✓ Yes" if config.get('ssl_enabled') else "✗ No"),
        ("SMTP Enabled", "✓ Yes" if config.get('smtp_enabled') else "✗ No"),
    ]
    
    for key, value in summary_items:
        console.print(f"  {key}: {value}")
    
    console.print()


def confirm_action(console: Console, question: str, default: bool = False) -> bool:
    """
    Prompt user for confirmation.
    
    Args:
        console: Rich console instance
        question: Question to ask user
        default: Default response if user just presses Enter
        
    Returns:
        True if user confirmed, False otherwise
    """
    prompt = f"{question} ({'Y/n' if default else 'y/N'}): "
    response = console.input(prompt).strip().lower()
    
    if not response:
        return default
    
    return response in ['y', 'yes']


def display_success_panel(
    console: Console,
    title: str,
    message: str,
    details: Optional[Dict[str, str]] = None
):
    """
    Display a success panel with optional details.
    
    Args:
        console: Rich console instance
        title: Panel title
        message: Main message
        details: Optional dictionary of detail items
    """
    content = f"[green]{message}[/green]\n"
    
    if details:
        content += "\n"
        for key, value in details.items():
            content += f"{key}: {value}\n"
    
    console.print(Panel(
        content,
        title=title,
        border_style="green"
    ))


def display_error_panel(
    console: Console,
    title: str,
    error: str,
    suggestion: Optional[str] = None
):
    """
    Display an error panel with optional suggestion.
    
    Args:
        console: Rich console instance
        title: Panel title
        error: Error message
        suggestion: Optional suggestion for resolution
    """
    content = f"[red]✗ {error}[/red]\n"
    
    if suggestion:
        content += f"\n{suggestion}"
    
    console.print(Panel(
        content,
        title=title,
        border_style="red"
    ))


def display_verification_table(
    console: Console,
    checks: Dict[str, tuple[bool, str]]
):
    """
    Display a verification results table.
    
    Args:
        console: Rich console instance
        checks: Dictionary mapping check names to (passed, details) tuples
    """
    table = Table(title="Verification Results", box=box.ROUNDED)
    table.add_column("Check", style="cyan")
    table.add_column("Status", style="yellow")
    table.add_column("Details", style="dim")
    
    for check_name, (passed, details) in checks.items():
        status = "[green]✓ Passed[/green]" if passed else "[red]✗ Failed[/red]"
        table.add_row(check_name, status, details)
    
    console.print(table)


def prompt_deployment_mode(console: Console) -> str:
    """
    Prompt user to select deployment mode.
    
    Args:
        console: Rich console instance
        
    Returns:
        "development" or "production"
    """
    console.print("[cyan]Select deployment mode:[/cyan]")
    console.print("  1. Development (local testing, verbose logging)")
    console.print("  2. Production (secure, optimized)")
    
    choice = console.input("\nChoice [1]: ").strip() or "1"
    
    return "development" if choice == "1" else "production"


class WorkflowStep:
    """
    Represents a step in a multi-step workflow.
    
    Useful for tracking progress through complex workflows.
    """
    
    def __init__(self, number: int, title: str, description: str):
        """
        Initialize workflow step.
        
        Args:
            number: Step number
            title: Step title
            description: Step description
        """
        self.number = number
        self.title = title
        self.description = description
        self.completed = False
        self.error = None
    
    def display_header(self, console: Console):
        """Display step header."""
        console.print(f"\n[bold yellow]Step {self.number}: {self.title}[/bold yellow]")
        if self.description:
            console.print(f"[dim]{self.description}[/dim]\n")
    
    def mark_completed(self):
        """Mark step as completed."""
        self.completed = True
    
    def mark_failed(self, error: str):
        """Mark step as failed with error message."""
        self.error = error
    
    def get_status(self) -> str:
        """Get step status string."""
        if self.completed:
            return "[green]✓ Complete[/green]"
        elif self.error:
            return f"[red]✗ Failed: {self.error}[/red]"
        else:
            return "[yellow]⏳ Pending[/yellow]"
