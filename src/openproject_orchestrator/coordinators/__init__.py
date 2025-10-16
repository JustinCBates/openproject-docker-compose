"""
Coordinators package

This package contains coordinator classes that wrap the submodule packages
and adapt them for use in the main orchestrator.

Coordinators:
- ConfigCoordinator: Wraps config-manager
- DeployCoordinator: Wraps deploy-manager (to be implemented in Phase 3)
"""

from openproject_orchestrator.coordinators.config_coordinator import (
    ConfigCoordinator,
    ConfigState,
)

__all__ = [
    "ConfigCoordinator",
    "ConfigState",
]
