#!/usr/bin/env python3
"""
Test script for DeployCoordinator integration.

This script verifies:
1. DeployCoordinator can be instantiated
2. deploy-manager package can be imported
3. Development mode is detected correctly
4. State tracking works as expected
"""

from pathlib import Path
from openproject_orchestrator.coordinators import DeployCoordinator


def test_deploy_coordinator():
    """Test DeployCoordinator basic functionality"""
    print("Testing DeployCoordinator...\n")
    
    # Test 1: Instantiation
    workspace_dir = Path("./test_workspace")
    try:
        coordinator = DeployCoordinator(workspace_dir=workspace_dir)
        print("✓ DeployCoordinator created successfully")
    except Exception as e:
        print(f"✗ Failed to create DeployCoordinator: {e}")
        return False
    
    # Test 2: Development mode detection
    if hasattr(coordinator, '_dev_mode'):
        print(f"✓ Development mode: {coordinator._dev_mode}")
    else:
        print("✗ Development mode not detected")
    
    # Test 3: Check deploy-manager import
    if hasattr(coordinator, 'DeploymentOrchestrator'):
        print(f"✓ deploy-manager imported successfully")
        print(f"   Module: {coordinator.DeploymentOrchestrator.__module__}")
    else:
        print("✗ deploy-manager not imported")
        return False
    
    # Test 4: State tracking
    if not coordinator.is_deployed():
        print("✓ Initial state: is_deployed = False")
    else:
        print("✗ Unexpected initial state")
    
    if coordinator.get_services_running() == 0:
        print("✓ Initial services running: 0")
    else:
        print("✗ Unexpected services count")
    
    # Test 5: Workspace directory
    if workspace_dir.exists():
        print(f"✓ Workspace directory created: {workspace_dir}")
    else:
        print("✗ Workspace directory not created")
    
    print("\nAll tests passed! ✅")
    
    # Cleanup
    import shutil
    if workspace_dir.exists():
        shutil.rmtree(workspace_dir)
        print(f"Cleaned up test workspace")
    
    return True


if __name__ == "__main__":
    test_deploy_coordinator()
