"""
OpenProject Orchestrator - Interactive TUI for OpenProject Deployment

This package provides an interactive terminal user interface (TUI) for deploying
and managing OpenProject. It orchestrates the config-manager and deploy-manager
submodules to provide a seamless deployment experience.

Main entry point: `openproject deploy`
"""

__version__ = "2.0.0"
__author__ = "OpenProject Contributors"

from openproject_orchestrator.tui_controller import TUIController

__all__ = ["TUIController", "__version__"]
