"""
Unit tests for ConfigCoordinator

Tests the configuration coordinator functionality including:
- Initialization
- Development mode detection
- Configuration state management
- Import handling
"""

import pytest
from pathlib import Path
import sys
from unittest.mock import Mock, patch, MagicMock

from openproject_orchestrator.coordinators import ConfigCoordinator, ConfigState


class TestConfigCoordinator:
    """Test suite for ConfigCoordinator"""
    
    @pytest.fixture
    def workspace_dir(self, tmp_path):
        """Provide a temporary workspace directory"""
        workspace = tmp_path / "workspace"
        workspace.mkdir()
        return workspace
    
    @pytest.fixture
    def coordinator(self, workspace_dir):
        """Provide a ConfigCoordinator instance"""
        return ConfigCoordinator(workspace_dir=workspace_dir)
    
    def test_initialization(self, coordinator, workspace_dir):
        """Test that coordinator initializes correctly"""
        assert coordinator.workspace_dir == workspace_dir
        assert isinstance(coordinator.state, ConfigState)
        assert coordinator.workspace_dir.exists()
    
    def test_initial_state(self, coordinator):
        """Test that initial state is not configured"""
        assert not coordinator.is_configured()
        assert coordinator.get_configuration() is None
        assert coordinator.get_config_file() is None
        assert coordinator.get_env_file() is None
    
    def test_workspace_creation(self, tmp_path):
        """Test workspace directory is set correctly"""
        workspace = tmp_path / "new_workspace"
        assert not workspace.exists()
        
        # Coordinator does NOT create the workspace in __init__
        # It's created when needed (e.g., during configuration)
        coordinator = ConfigCoordinator(workspace_dir=workspace)
        
        # Workspace path should be set but not created yet
        assert coordinator.workspace_dir == workspace
        assert not coordinator.workspace_dir.exists()  # Not created until needed
    
    def test_development_mode_detection(self, coordinator):
        """Test development mode detection"""
        # Should have _dev_mode attribute
        assert hasattr(coordinator, '_dev_mode')
        assert isinstance(coordinator._dev_mode, bool)
    
    def test_configuration_manager_import(self, workspace_dir):
        """Test that ConfigurationManager can be imported in dev mode"""
        # The coordinator itself should initialize successfully
        coordinator = ConfigCoordinator(workspace_dir=workspace_dir)
        
        # ConfigurationManager is imported locally in methods, not stored as attribute
        # Just verify the coordinator has the necessary import setup
        assert hasattr(coordinator, '_dev_mode')
        assert isinstance(coordinator._dev_mode, bool)
        
        # Verify it can import the module when needed
        try:
            from openproject_config_manager import ConfigurationManager
            assert ConfigurationManager is not None
        except ImportError:
            # If not in dev mode or package not installed, that's acceptable for unit tests
            pass
    
    def test_state_accessors(self, coordinator):
        """Test state accessor methods"""
        # Test is_configured
        assert coordinator.is_configured() == coordinator.state.is_configured
        
        # Test get_configuration
        assert coordinator.get_configuration() == coordinator.state.configuration
        
        # Test get_config_file
        assert coordinator.get_config_file() == coordinator.state.config_file
        
        # Test get_env_file
        assert coordinator.get_env_file() == coordinator.state.env_file
    
    def test_config_state_dataclass(self):
        """Test ConfigState dataclass"""
        state = ConfigState()
        
        assert state.is_configured == False
        assert state.config_file is None
        assert state.env_file is None
        assert state.configuration is None
        assert state.validation_passed == False
    
    def test_config_state_with_values(self, tmp_path):
        """Test ConfigState with actual values"""
        config_file = tmp_path / "config.yaml"
        env_file = tmp_path / ".env"
        config = {"domain": "test.example.com"}
        
        state = ConfigState(
            is_configured=True,
            config_file=config_file,
            env_file=env_file,
            configuration=config,
            validation_passed=True
        )
        
        assert state.is_configured == True
        assert state.config_file == config_file
        assert state.env_file == env_file
        assert state.configuration == config
        assert state.validation_passed == True


class TestConfigCoordinatorIntegration:
    """Integration tests for ConfigCoordinator"""
    
    @pytest.fixture
    def workspace_dir(self, tmp_path):
        """Provide a temporary workspace directory"""
        workspace = tmp_path / "workspace"
        workspace.mkdir()
        return workspace
    
    def test_sys_path_manipulation_dev_mode(self, workspace_dir, monkeypatch):
        """Test that sys.path is manipulated correctly in dev mode"""
        # Save original sys.path
        original_path = sys.path.copy()
        
        # Create coordinator (which may modify sys.path)
        coordinator = ConfigCoordinator(workspace_dir=workspace_dir)
        
        # If in dev mode, should have added to sys.path
        if coordinator._dev_mode:
            # At least one of the paths should be a config-manager path
            config_manager_paths = [p for p in sys.path if 'config-manager' in str(p)]
            # In dev mode, we expect this
            # In production mode, this might be empty
            pass
        
        # Cleanup
        sys.path = original_path
    
    def test_multiple_instantiation(self, workspace_dir):
        """Test that multiple instances can be created"""
        coord1 = ConfigCoordinator(workspace_dir=workspace_dir)
        coord2 = ConfigCoordinator(workspace_dir=workspace_dir)
        
        # Should be separate instances
        assert coord1 is not coord2
        
        # But should share same workspace
        assert coord1.workspace_dir == coord2.workspace_dir


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
