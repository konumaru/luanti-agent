# Luanti Agent - Python Client

Python client for controlling AI agents in Luanti via the agent_api mod.

## Features

- **Observation API**: Get agent position, orientation, surrounding blocks, nearby entities, and vision
- **Action API**: Control movement, rotation, digging, placing, and interactions
- **Type-safe**: Strongly typed data structures for observations and actions
- **Easy to use**: Simple client interface for sending commands

## Installation

This project uses [uv](https://docs.astral.sh/uv/) for dependency management.

```bash
# Install uv if you haven't already
pip install uv

# Install dependencies
cd agent
uv sync
```

## Quick Start

### Running the Bot Server

```bash
uv run python bot_server.py
```

This starts an HTTP server on port 8000 that the Luanti mod will poll for commands.

### Example Control Loop

```bash
# Wandering agent
uv run python example_control_loop.py wander

# Mining agent
uv run python example_control_loop.py mine

# Building agent
uv run python example_control_loop.py build
```

## Usage

### Basic Client

```python
from agent_client import AgentClient, MoveAction, RotateAction

# Create client
client = AgentClient(server_url="http://localhost:8000")

# Send actions
client.send_action(MoveAction("forward", speed=1.0))
client.send_action(RotateAction(yaw_delta=0.1))
```

### Available Actions

```python
# Movement
MoveAction("forward", speed=1.0)
MoveAction("backward", speed=1.0)
MoveAction("left", speed=1.0)
MoveAction("right", speed=1.0)
MoveAction("up", speed=1.0)
MoveAction("down", speed=1.0)

# Rotation
RotateAction(yaw_delta=0.1, pitch_delta=0.0)  # Relative rotation
LookAtAction(yaw=1.57, pitch=0.0)  # Absolute direction

# World interaction
DigAction()  # Dig block at look target
PlaceAction("default:stone")  # Place block
UseAction()  # Interact with target
```

### Observations

```python
from agent_client import Observation

# Get observation (when implemented)
obs = client.get_observation()

if obs:
    print(f"Position: {obs.position}")
    print(f"Health: {obs.health}")
    print(f"Looking at: {obs.look_target}")
    print(f"Nearby entities: {len(obs.nearby_entities)}")
    print(f"Surrounding blocks: {len(obs.surrounding_blocks)}")
```

## Architecture

```
┌─────────────────┐                    ┌──────────────────┐
│  Luanti Server  │                    │  Python Process  │
│   (Lua Mod)     │                    │                  │
│                 │                    │                  │
│  agent_api      │──── HTTP Poll ────▶│  bot_server.py   │
│  - observe()    │      /next         │  (command queue) │
│  - execute()    │◀─── Commands ──────│                  │
│                 │                    │                  │
│                 │                    │  agent_client.py │
│                 │                    │  (Python API)    │
└─────────────────┘                    └──────────────────┘
```

## Configuration

The Luanti mod can be configured via `minetest.conf`:

```ini
agent_api.bot_server_url = http://host.docker.internal:8000
agent_api.poll_interval = 0.2
agent_api.agent_name = AIAgent
agent_api.debug = false
```

## Development

### Project Structure

```
agent/
├── agent_client.py          # Main client API
├── bot_server.py            # HTTP server for command queue
├── example_control_loop.py  # Example behaviors
├── main.py                  # Entry point
├── pyproject.toml           # Package configuration
└── README.md                # This file
```

## License

See project LICENSE.
