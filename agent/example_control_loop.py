#!/usr/bin/env python3
"""Example control loop for Luanti AI agent

This script demonstrates a simple observe → act control loop using the agent API.
"""

import time
from agent_client import (
    AgentClient,
    MoveAction,
    RotateAction,
    DigAction,
    PlaceAction,
)


def simple_wandering_agent(client: AgentClient, duration: int = 60):
    """Simple agent that wanders around randomly
    
    Note: This example uses action-only control. Observation data is collected
    by the Lua mod but not yet sent to Python. Future enhancement will add
    observation-based decision making.
    
    Args:
        client: Agent client instance
        duration: How long to run (seconds)
    """
    print("Starting simple wandering agent...")
    print("Note: Currently using action-only control (no observation feedback)")
    start_time = time.time()
    action_counter = 0
    
    while time.time() - start_time < duration:
        # Simple behavior: alternate between moving forward and rotating
        if action_counter % 10 < 5:
            # Move forward
            client.send_action(MoveAction("forward", speed=1.0))
            print("→ Moving forward")
        else:
            # Rotate
            client.send_action(RotateAction(yaw_delta=0.2))
            print("→ Rotating")
        
        action_counter += 1
        time.sleep(1.0)
    
    print("Agent control loop finished")


def mining_agent(client: AgentClient):
    """Agent that mines blocks in front of it
    
    Args:
        client: Agent client instance
    """
    print("Starting mining agent...")
    
    for i in range(10):
        print(f"Mining cycle {i+1}/10")
        
        # Look at target and dig
        client.send_action(DigAction())
        time.sleep(0.5)
        
        # Move forward a bit
        client.send_action(MoveAction("forward", speed=0.5))
        time.sleep(0.5)
    
    print("Mining complete")


def building_agent(client: AgentClient):
    """Agent that builds a simple structure
    
    Args:
        client: Agent client instance
    """
    print("Starting building agent...")
    
    # Build a simple tower
    for i in range(5):
        print(f"Placing block {i+1}/5")
        
        # Place block
        client.send_action(PlaceAction("default:stone"))
        time.sleep(0.5)
        
        # Move up
        client.send_action(MoveAction("up", speed=1.0))
        time.sleep(0.5)
    
    print("Building complete")


def main():
    """Main entry point"""
    import sys
    
    # Create agent client
    client = AgentClient(server_url="http://localhost:8000")
    
    # Choose behavior based on command line argument
    if len(sys.argv) > 1:
        behavior = sys.argv[1]
    else:
        behavior = "wander"
    
    print(f"Agent behavior: {behavior}")
    print(f"Server: {client.server_url}")
    print()
    
    try:
        if behavior == "wander":
            simple_wandering_agent(client, duration=60)
        elif behavior == "mine":
            mining_agent(client)
        elif behavior == "build":
            building_agent(client)
        else:
            print(f"Unknown behavior: {behavior}")
            print("Available behaviors: wander, mine, build")
            sys.exit(1)
    except KeyboardInterrupt:
        print("\nStopping agent...")
    
    print("Done!")


if __name__ == "__main__":
    main()
