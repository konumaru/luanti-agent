#!/usr/bin/env python3
"""Simple test to verify agent_client module loads and basic functionality works"""

import sys

def test_imports():
    """Test that all required modules can be imported"""
    print("Testing imports...")
    try:
        from agent_client import (
            AgentClient,
            Position,
            Orientation,
            Block,
            Entity,
            LookTarget,
            Observation,
            MoveAction,
            RotateAction,
            LookAtAction,
            DigAction,
            PlaceAction,
            UseAction,
            SetObservationOptionsAction,
            ChatAction,
        )
        print("✓ All imports successful")
        return True
    except ImportError as e:
        print(f"✗ Import failed: {e}")
        return False


def test_data_structures():
    """Test that data structures can be created"""
    print("\nTesting data structures...")
    try:
        from agent_client import Position, MoveAction, RotateAction
        
        # Test Position
        pos = Position(x=1.0, y=2.0, z=3.0)
        assert pos.x == 1.0
        assert pos.to_dict() == {'x': 1.0, 'y': 2.0, 'z': 3.0}
        
        # Test Position.from_dict
        pos2 = Position.from_dict({'x': 4.0, 'y': 5.0, 'z': 6.0})
        assert pos2.x == 4.0
        
        print("✓ Position works")
        
        # Test MoveAction
        move = MoveAction("forward", speed=2.0)
        action_dict = move.to_dict()
        assert action_dict['type'] == 'move'
        assert action_dict['direction'] == 'forward'
        assert action_dict['speed'] == 2.0
        
        print("✓ MoveAction works")
        
        # Test RotateAction
        rotate = RotateAction(yaw_delta=0.5, pitch_delta=0.1)
        action_dict = rotate.to_dict()
        assert action_dict['type'] == 'rotate'
        assert action_dict['yaw_delta'] == 0.5
        
        print("✓ RotateAction works")
        
        return True
    except Exception as e:
        print(f"✗ Data structure test failed: {e}")
        return False


def test_client_creation():
    """Test that AgentClient can be created"""
    print("\nTesting client creation...")
    try:
        from agent_client import AgentClient
        
        client = AgentClient("http://localhost:8000")
        assert client.server_url == "http://localhost:8000"
        
        print("✓ AgentClient creation works")
        return True
    except Exception as e:
        print(f"✗ Client creation failed: {e}")
        return False


def test_action_serialization():
    """Test that all action types serialize correctly"""
    print("\nTesting action serialization...")
    try:
        from agent_client import (
            MoveAction, RotateAction, LookAtAction,
            DigAction, PlaceAction, UseAction,
            SetObservationOptionsAction, ChatAction
        )
        
        actions = [
            MoveAction("forward", speed=1.0),
            RotateAction(yaw_delta=0.5),
            LookAtAction(yaw=1.57),
            DigAction(),
            PlaceAction("default:stone"),
            UseAction(),
            SetObservationOptionsAction(filter_occluded_blocks=True),
            ChatAction("Hello from agent!"),
        ]
        
        for action in actions:
            action_dict = action.to_dict()
            assert 'type' in action_dict
            print(f"✓ {action.__class__.__name__} serialization works")
        
        # Test SetObservationOptionsAction specifically
        obs_action = SetObservationOptionsAction(filter_occluded_blocks=False)
        obs_dict = obs_action.to_dict()
        assert obs_dict['type'] == 'set_observation_options'
        assert obs_dict['options']['filter_occluded_blocks'] == False
        
        # Test ChatAction specifically
        chat_action = ChatAction("Test message")
        chat_dict = chat_action.to_dict()
        assert chat_dict['type'] == 'chat'
        assert chat_dict['message'] == "Test message"
        
        return True
    except Exception as e:
        print(f"✗ Action serialization failed: {e}")
        return False


def main():
    """Run all tests"""
    print("=" * 60)
    print("Agent Client Module Tests")
    print("=" * 60)
    
    tests = [
        test_imports,
        test_data_structures,
        test_client_creation,
        test_action_serialization,
    ]
    
    results = []
    for test in tests:
        results.append(test())
    
    print("\n" + "=" * 60)
    passed = sum(results)
    total = len(results)
    print(f"Results: {passed}/{total} tests passed")
    print("=" * 60)
    
    if passed == total:
        print("\n✓ All tests passed!")
        return 0
    else:
        print(f"\n✗ {total - passed} test(s) failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
