#!/usr/bin/env python3
"""
Simple test to verify ConfigCoordinator can import config-manager
"""

import sys
from pathlib import Path

# Add the orchestrator to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from openproject_orchestrator.coordinators import ConfigCoordinator
from rich.console import Console

console = Console()

def test_config_coordinator_import():
    """Test that ConfigCoordinator can be imported and instantiated"""
    console.print("[cyan]Testing ConfigCoordinator...[/cyan]\n")
    
    try:
        # Create coordinator
        coordinator = ConfigCoordinator()
        console.print("[green]✓[/green] ConfigCoordinator created successfully")
        
        # Check development mode
        console.print(f"[green]✓[/green] Development mode: {coordinator._dev_mode}")
        
        # Check if config-manager can be imported
        try:
            from openproject_config_manager import ConfigurationManager
            console.print("[green]✓[/green] config-manager imported successfully")
            console.print(f"[dim]   Module: {ConfigurationManager.__module__}[/dim]")
        except ImportError as e:
            console.print(f"[red]✗[/red] Could not import config-manager: {e}")
            return False
        
        # Check state
        console.print(f"[green]✓[/green] Is configured: {coordinator.is_configured()}")
        
        console.print("\n[green]All tests passed![/green]\n")
        return True
        
    except Exception as e:
        console.print(f"[red]✗[/red] Error: {e}")
        import traceback
        console.print(traceback.format_exc())
        return False

if __name__ == "__main__":
    success = test_config_coordinator_import()
    sys.exit(0 if success else 1)
