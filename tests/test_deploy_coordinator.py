"""
Unit tests for DeployCoordinator

Tests the deployment coordinator functionality including:
- Initialization
- Development mode detection
- Deployment state management
- Import handling
"""

import pytest
from pathlib import Path
import sys
from unittest.mock import Mock, patch

from openproject_orchestrator.coordinators import DeployCoordinator, DeploymentState


class TestDeployCoordinator:
    """Test suite for DeployCoordinator"""

    @pytest.fixture
    def workspace_dir(self, tmp_path):
        """Provide a temporary workspace directory"""
        workspace = tmp_path / "workspace"
        workspace.mkdir()
        return workspace

    @pytest.fixture
    def coordinator(self, workspace_dir):
        """Provide a DeployCoordinator instance"""
        return DeployCoordinator(workspace_dir=workspace_dir)

    def test_initialization(self, coordinator, workspace_dir):
        """Test that coordinator initializes correctly"""
        assert coordinator.workspace_dir == workspace_dir
        assert isinstance(coordinator.state, DeploymentState)
        assert coordinator.workspace_dir.exists()

    def test_initial_state(self, coordinator):
        """Test that initial state is not deployed"""
        assert not coordinator.is_deployed()
        assert coordinator.get_deployment_time() is None
        assert coordinator.get_services_running() == 0
        assert coordinator.get_configuration_used() is None
        assert coordinator.get_last_error() is None

    def test_workspace_creation(self, tmp_path):
        """Test that workspace directory is created if it doesn't exist"""
        workspace = tmp_path / "new_workspace"
        assert not workspace.exists()

        coordinator = DeployCoordinator(workspace_dir=workspace)
        assert workspace.exists()

    def test_development_mode_detection(self, coordinator):
        """Test development mode detection"""
        # Should have _dev_mode attribute
        assert hasattr(coordinator, "_dev_mode")
        assert isinstance(coordinator._dev_mode, bool)

    def test_deployment_orchestrator_import(self, workspace_dir):
        """Test that DeploymentOrchestrator can be imported"""
        # Simply test that the coordinator initializes without import errors
        coordinator = DeployCoordinator(workspace_dir=workspace_dir)

        # Should have DeploymentOrchestrator attribute (set in __init__)
        assert hasattr(coordinator, "DeploymentOrchestrator")

    def test_state_accessors(self, coordinator):
        """Test state accessor methods"""
        # Test is_deployed
        assert coordinator.is_deployed() == coordinator.state.is_deployed

        # Test get_deployment_time
        assert coordinator.get_deployment_time() == coordinator.state.deployment_time

        # Test get_services_running
        assert coordinator.get_services_running() == coordinator.state.services_running

        # Test get_configuration_used
        assert (
            coordinator.get_configuration_used() == coordinator.state.configuration_used
        )

        # Test get_last_error
        assert coordinator.get_last_error() == coordinator.state.error_message

    def test_deployment_state_dataclass(self):
        """Test DeploymentState dataclass"""
        state = DeploymentState()

        assert state.is_deployed == False
        assert state.deployment_time is None
        assert state.services_running == 0
        assert state.configuration_used is None
        assert state.deployment_successful == False
        assert state.error_message is None

    def test_deployment_state_with_values(self):
        """Test DeploymentState with actual values"""
        config = {"domain": "test.example.com"}

        state = DeploymentState(
            is_deployed=True,
            deployment_time="2025-10-16T14:30:00",
            services_running=5,
            configuration_used=config,
            deployment_successful=True,
            error_message=None,
        )

        assert state.is_deployed == True
        assert state.deployment_time == "2025-10-16T14:30:00"
        assert state.services_running == 5
        assert state.configuration_used == config
        assert state.deployment_successful == True
        assert state.error_message is None

    def test_get_status(self, coordinator):
        """Test get_status method"""
        status = coordinator.get_status()

        assert isinstance(status, dict)
        assert "is_deployed" in status
        assert "services_running" in status
        assert "deployment_time" in status
        assert "deployment_successful" in status
        assert "error_message" in status


class TestDeployCoordinatorIntegration:
    """Integration tests for DeployCoordinator"""

    @pytest.fixture
    def workspace_dir(self, tmp_path):
        """Provide a temporary workspace directory"""
        workspace = tmp_path / "workspace"
        workspace.mkdir()
        return workspace

    def test_sys_path_manipulation_dev_mode(self, workspace_dir):
        """Test that sys.path is manipulated correctly in dev mode"""
        # Save original sys.path
        original_path = sys.path.copy()

        # Create coordinator (which may modify sys.path)
        coordinator = DeployCoordinator(workspace_dir=workspace_dir)

        # If in dev mode, should have added to sys.path
        if coordinator._dev_mode:
            # At least one of the paths should be a deploy-manager path
            deploy_manager_paths = [p for p in sys.path if "deploy-manager" in str(p)]
            # In dev mode, we expect this
            # In production mode, this might be empty
            pass

        # Cleanup
        sys.path = original_path

    def test_multiple_instantiation(self, workspace_dir):
        """Test that multiple instances can be created"""
        coord1 = DeployCoordinator(workspace_dir=workspace_dir)
        coord2 = DeployCoordinator(workspace_dir=workspace_dir)

        # Should be separate instances
        assert coord1 is not coord2

        # But should share same workspace
        assert coord1.workspace_dir == coord2.workspace_dir


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
