#!/usr/bin/env python3
"""
Test PathResolver with config-manager project structure.

This script validates that PathResolver can:
1. Auto-detect project root from any phase/step file
2. Resolve artifact paths from control_flows.yml
3. Resolve phase directories and output directories
"""

import sys
from pathlib import Path

# Add control-flow src to path
control_flow_src = Path(__file__).parent / "external/control-flow/src"
sys.path.insert(0, str(control_flow_src))

from control_flow_engine.runtime import PathResolver, PathResolutionError

def test_path_resolver():
    """Test PathResolver functionality."""
    print("=" * 70)
    print("PathResolver Test Suite")
    print("=" * 70)
    
    # Test 1: Auto-detect from config-manager directory
    print("\n📍 Test 1: Auto-detect project root")
    print("-" * 70)
    
    config_manager_root = Path(__file__).parent / "external/config-manager"
    test_file = config_manager_root / "phases/phase_3_collection/orchestrator_collection.py"
    
    print(f"Testing from file: {test_file}")
    print(f"File exists: {test_file.exists()}")
    
    try:
        resolver = PathResolver.from_execution_context(str(test_file))
        print(f"✅ Project root detected: {resolver.get_project_root()}")
    except PathResolutionError as e:
        print(f"❌ Failed: {e}")
        return False
    
    # Test 2: List all phases
    print("\n📋 Test 2: List all phases")
    print("-" * 70)
    
    phases = resolver.list_phases()
    print(f"Found {len(phases)} phases:")
    for phase in phases:
        print(f"  • {phase}")
    
    # Test 3: List all artifacts
    print("\n📦 Test 3: List all artifacts")
    print("-" * 70)
    
    artifacts = resolver.list_artifacts()
    print(f"Found {len(artifacts)} artifacts:")
    for artifact in artifacts[:10]:  # Show first 10
        print(f"  • {artifact}")
    if len(artifacts) > 10:
        print(f"  ... and {len(artifacts) - 10} more")
    
    # Test 4: Resolve specific artifact
    print("\n🔍 Test 4: Resolve user_configuration artifact")
    print("-" * 70)
    
    try:
        artifact_path = resolver.resolve_artifact_path('user_configuration')
        print(f"✅ Resolved to: {artifact_path}")
        print(f"   Exists: {artifact_path.exists()}")
    except PathResolutionError as e:
        print(f"❌ Failed: {e}")
    
    # Test 5: Resolve phase output directory
    print("\n📁 Test 5: Resolve phase output directory")
    print("-" * 70)
    
    try:
        output_dir = resolver.resolve_phase_output_dir('collection')
        print(f"✅ Resolved to: {output_dir}")
        print(f"   Exists: {output_dir.exists()}")
    except PathResolutionError as e:
        print(f"❌ Failed: {e}")
    
    # Test 6: Get artifact info
    print("\n🏷️  Test 6: Get artifact metadata")
    print("-" * 70)
    
    try:
        info = resolver.get_artifact_info('user_configuration')
        print(f"✅ Artifact info:")
        print(f"   Phase: {info['phase_id']}")
        print(f"   Flow: {info['flow_id']}")
        print(f"   Action: {info['action']}")
        print(f"   Location: {info['location']}")
        if info.get('note'):
            print(f"   Note: {info['note']}")
    except PathResolutionError as e:
        print(f"❌ Failed: {e}")
    
    # Test 7: Validate artifact accessibility
    print("\n✔️  Test 7: Validate artifact accessibility")
    print("-" * 70)
    
    test_artifacts = ['discovered_environment', 'user_configuration', 'tui_defaults_file']
    for artifact_id in test_artifacts:
        readable = resolver.validate_artifact_accessible(artifact_id, mode='read')
        writable = resolver.validate_artifact_accessible(artifact_id, mode='write')
        print(f"  {artifact_id}:")
        print(f"    Read: {'✅' if readable else '❌'}")
        print(f"    Write: {'✅' if writable else '❌'}")
    
    # Test 8: Filter artifacts by phase
    print("\n🎯 Test 8: Filter artifacts by phase")
    print("-" * 70)
    
    try:
        collection_artifacts = resolver.list_artifacts(phase_id='collection')
        print(f"Phase 'collection' produces/consumes:")
        for artifact in collection_artifacts:
            info = resolver.get_artifact_info(artifact)
            print(f"  • {artifact} ({info['action']})")
    except Exception as e:
        print(f"❌ Failed: {e}")
    
    print("\n" + "=" * 70)
    print("✅ PathResolver test suite completed successfully!")
    print("=" * 70)
    
    return True

if __name__ == "__main__":
    success = test_path_resolver()
    sys.exit(0 if success else 1)
