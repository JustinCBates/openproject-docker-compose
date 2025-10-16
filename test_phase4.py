#!/usr/bin/env python3
"""
Test script for Phase 4 implementation.

This script verifies:
1. Workflow helpers module works
2. Quick Deploy workflow logic is integrated
3. Enhanced status dashboard functionality
4. All imports are working correctly
"""

from pathlib import Path
from openproject_orchestrator.workflows import (
    display_workflow_header,
    display_configuration_summary,
    confirm_action,
    WorkflowStep,
)
from rich.console import Console


def test_workflow_helpers():
    """Test workflow helper functions"""
    print("Testing workflow helpers...\n")
    
    console = Console()
    
    # Test 1: Workflow header display
    try:
        display_workflow_header(console, "Test Workflow", "This is a test")
        print("✓ display_workflow_header works")
    except Exception as e:
        print(f"✗ display_workflow_header failed: {e}")
        return False
    
    # Test 2: Configuration summary
    test_config = {
        'domain': 'test.example.com',
        'admin_email': 'admin@example.com',
        'ssl_enabled': True,
        'smtp_enabled': False
    }
    
    try:
        display_configuration_summary(console, test_config)
        print("✓ display_configuration_summary works")
    except Exception as e:
        print(f"✗ display_configuration_summary failed: {e}")
        return False
    
    # Test 3: WorkflowStep class
    try:
        step = WorkflowStep(1, "Test Step", "This is a test step")
        step.display_header(console)
        status = step.get_status()
        print(f"✓ WorkflowStep class works (status: {status})")
    except Exception as e:
        print(f"✗ WorkflowStep class failed: {e}")
        return False
    
    # Test 4: Step completion
    try:
        step.mark_completed()
        status = step.get_status()
        if "Complete" in status:
            print(f"✓ WorkflowStep completion works")
        else:
            print(f"✗ WorkflowStep completion status incorrect: {status}")
            return False
    except Exception as e:
        print(f"✗ WorkflowStep completion failed: {e}")
        return False
    
    return True


def test_tui_integration():
    """Test TUI Controller integration"""
    print("\nTesting TUI Controller integration...\n")
    
    try:
        from openproject_orchestrator.tui_controller import TUIController
        print("✓ TUIController imported successfully")
    except Exception as e:
        print(f"✗ Failed to import TUIController: {e}")
        return False
    
    # Test instantiation
    try:
        controller = TUIController(debug=True)
        print("✓ TUIController instantiated successfully")
    except Exception as e:
        print(f"✗ Failed to instantiate TUIController: {e}")
        return False
    
    # Verify coordinators
    if hasattr(controller, 'config_coordinator'):
        print("✓ ConfigCoordinator integrated")
    else:
        print("✗ ConfigCoordinator not found")
        return False
    
    if hasattr(controller, 'deploy_coordinator'):
        print("✓ DeployCoordinator integrated")
    else:
        print("✗ DeployCoordinator not found")
        return False
    
    # Check for workflow methods
    workflow_methods = [
        '_workflow_quick_deploy',
        '_workflow_configure',
        '_workflow_deploy',
        '_show_status_dashboard'
    ]
    
    for method in workflow_methods:
        if hasattr(controller, method):
            print(f"✓ Method {method} exists")
        else:
            print(f"✗ Method {method} not found")
            return False
    
    return True


def test_package_structure():
    """Test package structure"""
    print("\nTesting package structure...\n")
    
    # Test imports
    try:
        from openproject_orchestrator import __version__
        print(f"✓ Package version: {__version__}")
    except Exception as e:
        print(f"✗ Failed to get package version: {e}")
        return False
    
    # Test coordinators package
    try:
        from openproject_orchestrator.coordinators import (
            ConfigCoordinator,
            DeployCoordinator
        )
        print("✓ Coordinators package imports work")
    except Exception as e:
        print(f"✗ Coordinators package import failed: {e}")
        return False
    
    # Test workflows package
    try:
        from openproject_orchestrator.workflows import (
            display_workflow_header,
            WorkflowStep
        )
        print("✓ Workflows package imports work")
    except Exception as e:
        print(f"✗ Workflows package import failed: {e}")
        return False
    
    return True


def main():
    """Run all tests"""
    print("=" * 70)
    print("PHASE 4 IMPLEMENTATION TEST")
    print("=" * 70)
    print()
    
    tests = [
        ("Package Structure", test_package_structure),
        ("Workflow Helpers", test_workflow_helpers),
        ("TUI Integration", test_tui_integration),
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"\n{'=' * 70}")
        print(f"TEST: {test_name}")
        print(f"{'=' * 70}")
        result = test_func()
        results.append((test_name, result))
    
    # Summary
    print("\n" + "=" * 70)
    print("TEST SUMMARY")
    print("=" * 70)
    print()
    
    all_passed = True
    for test_name, result in results:
        status = "✅ PASSED" if result else "❌ FAILED"
        print(f"{test_name}: {status}")
        if not result:
            all_passed = False
    
    print()
    if all_passed:
        print("=" * 70)
        print("ALL TESTS PASSED! ✅")
        print("=" * 70)
        return 0
    else:
        print("=" * 70)
        print("SOME TESTS FAILED! ❌")
        print("=" * 70)
        return 1


if __name__ == "__main__":
    exit(main())
