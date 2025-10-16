"""
OpenProject Deploy - Orchestration layer for OpenProject deployment

This package serves as the orchestration layer for OpenProject deployment,
coordinating the config-manager and deploy-manager submodules while providing
OpenProject-specific functionality (backup, upgrade, migrations).

Architecture:
- Main repo (this): CLI orchestration + OpenProject-specific features
- config-manager: Interactive configuration (auto-discovery, TUI, validation)
- deploy-manager: Deployment orchestration (templates, Docker, health checks)

Note: Configuration and deployment logic have been moved to standalone submodules.
This allows them to be reused for any Docker Compose project while this package
provides OpenProject-specific integration.

Submodules:
- external/config-manager: 5-phase configuration workflow
  Import: from openproject_config_manager import ConfigurationManager
  
- external/deploy-manager: Deployment orchestration system
  Import: from openproject_deploy_manager import DeploymentOrchestrator

Future: CLI orchestrator will be implemented in openproject_cli package.

See also:
- docs/SRC_CODE_MIGRATION_ANALYSIS.md - Migration analysis and plan
- docs/architecture/ARCHITECTURE.md - Multi-repository architecture
- docs/SUBMODULE_DOCUMENTATION.md - Submodule documentation index
"""

__version__ = "2.0.0"

# ConfigManager has been moved to external/config-manager submodule
# Use: from openproject_config_manager import ConfigurationManager

# DeploymentOrchestrator lives in external/deploy-manager submodule
# Use: from openproject_deploy_manager import DeploymentOrchestrator
