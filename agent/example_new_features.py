#!/usr/bin/env python3
"""Example demonstrating the new agent features: visibility filtering and chat

This script shows how to:
1. Enable/disable occlusion filtering for observations
2. Send chat messages from the agent
"""

import time
from agent_client import (
    AgentClient,
    MoveAction,
    RotateAction,
    SetObservationOptionsAction,
    ChatAction,
)


def visibility_demo(client: AgentClient):
    """Demonstrate visibility filtering
    
    Args:
        client: Agent client instance
    """
    print("=== Visibility Filtering Demo ===")
    
    # Greet in chat
    client.send_action(ChatAction("Starting visibility demo!"))
    time.sleep(1)
    
    # Disable occlusion filtering (see all blocks)
    print("→ Disabling occlusion filter (agent will see underground blocks)")
    client.send_action(SetObservationOptionsAction(filter_occluded_blocks=False))
    client.send_action(ChatAction("I can see underground blocks now"))
    time.sleep(2)
    
    # Enable occlusion filtering (only visible blocks)
    print("→ Enabling occlusion filter (agent will only see visible blocks)")
    client.send_action(SetObservationOptionsAction(filter_occluded_blocks=True))
    client.send_action(ChatAction("Now I can only see visible blocks"))
    time.sleep(2)
    
    print("✓ Visibility filtering demo complete")


def chat_demo(client: AgentClient):
    """Demonstrate chat functionality
    
    Args:
        client: Agent client instance
    """
    print("\n=== Chat Demo ===")
    
    messages = [
        "Hello, everyone!",
        "I am an AI agent",
        "I can explore and interact with the world",
        "This is pretty cool!",
    ]
    
    for i, msg in enumerate(messages, 1):
        print(f"→ Sending message {i}/{len(messages)}: {msg}")
        client.send_action(ChatAction(msg))
        time.sleep(2)
    
    print("✓ Chat demo complete")


def combined_demo(client: AgentClient):
    """Combine movement, visibility, and chat
    
    Args:
        client: Agent client instance
    """
    print("\n=== Combined Demo ===")
    
    # Start with greeting
    client.send_action(ChatAction("Starting exploration with visibility filtering"))
    time.sleep(1)
    
    # Enable visibility filtering
    client.send_action(SetObservationOptionsAction(filter_occluded_blocks=True))
    client.send_action(ChatAction("Occlusion filter enabled"))
    time.sleep(1)
    
    # Move and comment
    for i in range(3):
        client.send_action(MoveAction("forward", speed=1.0))
        client.send_action(ChatAction(f"Moving forward (step {i+1})"))
        time.sleep(2)
        
        client.send_action(RotateAction(yaw_delta=0.5))
        client.send_action(ChatAction("Rotating to scan area"))
        time.sleep(1)
    
    client.send_action(ChatAction("Exploration complete!"))
    print("✓ Combined demo complete")


def main():
    """Main entry point"""
    import sys
    
    # Create agent client
    client = AgentClient(server_url="http://localhost:8000")
    
    # Choose demo based on command line argument
    if len(sys.argv) > 1:
        demo = sys.argv[1]
    else:
        demo = "combined"
    
    print(f"Agent Demo: {demo}")
    print(f"Server: {client.server_url}")
    print()
    
    try:
        if demo == "visibility":
            visibility_demo(client)
        elif demo == "chat":
            chat_demo(client)
        elif demo == "combined":
            combined_demo(client)
        else:
            print(f"Unknown demo: {demo}")
            print("Available demos: visibility, chat, combined")
            sys.exit(1)
    except KeyboardInterrupt:
        print("\n\nDemo interrupted")
    
    print("\nDone!")


if __name__ == "__main__":
    main()
