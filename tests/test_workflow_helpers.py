"""
Unit tests for workflow helpers

Tests the workflow helper functions and classes.
"""

import pytest
from unittest.mock import Mock, MagicMock
from rich.console import Console

from openproject_orchestrator.workflows import (
    display_workflow_header,
    display_configuration_summary,
    confirm_action,
    display_success_panel,
    display_error_panel,
    display_verification_table,
    prompt_deployment_mode,
    WorkflowStep,
)


class TestWorkflowHelpers:
    """Test suite for workflow helper functions"""
    
    @pytest.fixture
    def console(self):
        """Provide a mock console"""
        return Mock(spec=Console)
    
    def test_display_workflow_header(self, console):
        """Test workflow header display"""
        display_workflow_header(console, "Test Workflow", "This is a test")
        
        # Should print two things: title and description
        assert console.print.call_count >= 2
    
    def test_display_configuration_summary(self, console):
        """Test configuration summary display"""
        config = {
            'domain': 'test.example.com',
            'admin_email': 'admin@test.com',
            'ssl_enabled': True,
            'smtp_enabled': False
        }
        
        display_configuration_summary(console, config)
        
        # Should print header and items
        assert console.print.called
    
    def test_confirm_action_default_true(self, console):
        """Test confirmation with default True"""
        console.input.return_value = ""  # Just press Enter
        
        result = confirm_action(console, "Continue?", default=True)
        
        assert result == True
        console.input.assert_called_once()
    
    def test_confirm_action_default_false(self, console):
        """Test confirmation with default False"""
        console.input.return_value = ""  # Just press Enter
        
        result = confirm_action(console, "Continue?", default=False)
        
        assert result == False
        console.input.assert_called_once()
    
    def test_confirm_action_yes(self, console):
        """Test confirmation with 'yes'"""
        console.input.return_value = "yes"
        
        result = confirm_action(console, "Continue?", default=False)
        
        assert result == True
    
    def test_confirm_action_no(self, console):
        """Test confirmation with 'no'"""
        console.input.return_value = "no"
        
        result = confirm_action(console, "Continue?", default=True)
        
        assert result == False
    
    def test_display_success_panel(self, console):
        """Test success panel display"""
        display_success_panel(
            console,
            "Success",
            "Operation completed",
            {"Domain": "test.com", "Email": "admin@test.com"}
        )
        
        console.print.assert_called_once()
    
    def test_display_error_panel(self, console):
        """Test error panel display"""
        display_error_panel(
            console,
            "Error",
            "Something went wrong",
            "Try again later"
        )
        
        console.print.assert_called_once()
    
    def test_display_verification_table(self, console):
        """Test verification table display"""
        checks = {
            "Configuration": (True, "Valid configuration"),
            "Deployment": (False, "Not deployed"),
        }
        
        display_verification_table(console, checks)
        
        console.print.assert_called_once()
    
    def test_prompt_deployment_mode_development(self, console):
        """Test deployment mode prompt - development"""
        console.input.return_value = "1"
        
        mode = prompt_deployment_mode(console)
        
        assert mode == "development"
    
    def test_prompt_deployment_mode_production(self, console):
        """Test deployment mode prompt - production"""
        console.input.return_value = "2"
        
        mode = prompt_deployment_mode(console)
        
        assert mode == "production"
    
    def test_prompt_deployment_mode_default(self, console):
        """Test deployment mode prompt - default"""
        console.input.return_value = ""  # Just press Enter
        
        mode = prompt_deployment_mode(console)
        
        assert mode == "development"  # Default is development


class TestWorkflowStep:
    """Test suite for WorkflowStep class"""
    
    @pytest.fixture
    def console(self):
        """Provide a mock console"""
        return Mock(spec=Console)
    
    def test_initialization(self):
        """Test WorkflowStep initialization"""
        step = WorkflowStep(1, "Test Step", "This is a test")
        
        assert step.number == 1
        assert step.title == "Test Step"
        assert step.description == "This is a test"
        assert step.completed == False
        assert step.error is None
    
    def test_display_header(self, console):
        """Test step header display"""
        step = WorkflowStep(1, "Test Step", "This is a test")
        step.display_header(console)
        
        # Should print at least 2 things (title and description)
        assert console.print.call_count >= 2
    
    def test_mark_completed(self):
        """Test marking step as completed"""
        step = WorkflowStep(1, "Test Step", "Description")
        
        assert step.completed == False
        step.mark_completed()
        assert step.completed == True
    
    def test_mark_failed(self):
        """Test marking step as failed"""
        step = WorkflowStep(1, "Test Step", "Description")
        
        assert step.error is None
        step.mark_failed("Test error")
        assert step.error == "Test error"
    
    def test_get_status_pending(self):
        """Test status for pending step"""
        step = WorkflowStep(1, "Test Step", "Description")
        
        status = step.get_status()
        assert "Pending" in status
    
    def test_get_status_completed(self):
        """Test status for completed step"""
        step = WorkflowStep(1, "Test Step", "Description")
        step.mark_completed()
        
        status = step.get_status()
        assert "Complete" in status
    
    def test_get_status_failed(self):
        """Test status for failed step"""
        step = WorkflowStep(1, "Test Step", "Description")
        step.mark_failed("Test error")
        
        status = step.get_status()
        assert "Failed" in status
        assert "Test error" in status


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
