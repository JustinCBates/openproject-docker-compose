"""
CLI entry point for OpenProject orchestrator

Provides the main command-line interface:
    openproject deploy      - Launch interactive TUI
    openproject --version   - Show version
    openproject --help      - Show help
"""

import click
from rich.console import Console

from openproject_orchestrator import __version__
from openproject_orchestrator.tui_controller import TUIController
from openproject_orchestrator.utils import setup_logging, get_logger


console = Console()
logger = None  # Will be initialized after setup_logging


@click.group(invoke_without_command=True)
@click.option('--version', is_flag=True, help='Show version and exit')
@click.pass_context
def main(ctx, version):
    """
    OpenProject Deployment Orchestrator
    
    Interactive TUI for deploying and managing OpenProject.
    """
    if version:
        console.print(f"[cyan]OpenProject Orchestrator[/cyan] v{__version__}")
        ctx.exit(0)
    
    # If no subcommand provided, show help
    if ctx.invoked_subcommand is None:
        click.echo(ctx.get_help())


@main.command()
@click.option('--debug', is_flag=True, help='Enable debug mode')
def deploy(debug):
    """
    Launch interactive deployment TUI
    
    This is the main entry point for deploying OpenProject.
    It provides a guided, interactive workflow for:
    
    \b
    - Configuring OpenProject
    - Deploying containers
    - Viewing deployment status
    
    Example:
        openproject deploy
    """
    global logger
    
    try:
        # Setup logging
        setup_logging(debug=debug)
        logger = get_logger(__name__)
        logger.info("=" * 70)
        logger.info("OpenProject Orchestrator started")
        logger.info(f"Version: {__version__}")
        logger.info(f"Debug mode: {debug}")
        logger.info("=" * 70)
        
        # Launch TUI
        controller = TUIController(debug=debug)
        controller.run()
        
        logger.info("OpenProject Orchestrator exited normally")
        
    except KeyboardInterrupt:
        if logger:
            logger.info("Deployment cancelled by user (KeyboardInterrupt)")
        console.print("\n[yellow]Deployment cancelled by user[/yellow]")
    except Exception as e:
        if logger:
            logger.error(f"Unhandled exception: {e}", exc_info=True)
        console.print(f"\n[red]Error:[/red] {e}")
        if debug:
            import traceback
            console.print(traceback.format_exc())
        raise click.Abort()


@main.command()
def version():
    """Show version information"""
    console.print(f"[cyan]OpenProject Orchestrator[/cyan] v{__version__}")
    console.print("\n[dim]Components:[/dim]")
    console.print("  • config-manager: v2.0.0")
    console.print("  • deploy-manager: v2.0.0")


if __name__ == "__main__":
    main()
