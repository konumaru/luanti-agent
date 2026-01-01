# Quick Start Guide

This guide will help you set up and use the Luanti Agent API.

## Prerequisites

- Docker and Docker Compose
- Python 3.13+
- A Luanti client to connect to the server

## Step 1: Start the Luanti Server

```bash
cd luanti-agent
docker compose up -d
```

This will:
- Start a Luanti server on port 30000/udp
- Initialize a reproducible world with fixed seed
- Mount the agent_api mod

Check server logs:
```bash
docker compose logs -f luanti
```

## Step 2: Start the Python Bot Server

In a new terminal:

```bash
cd agent
# Install uv if you haven't already
pip install uv

# Install dependencies and run bot server
uv sync
uv run python bot_server.py
```

This starts an HTTP server on `localhost:8000` that the Luanti mod will poll for commands.

You should see:
```
python bot server listening on http://0.0.0.0:8000
```

## Step 3: Connect to the Server and Create an Agent

1. Open your Luanti client
2. Connect to `localhost:30000`
3. Create a player account if needed
4. Once in-game, open chat (T key) and type:

```
/agent_create
```

You should see: `Agent created for player: YourUsername`

## Step 4: Control Your Agent from Python

In a third terminal:

```bash
cd agent
python example_control_loop.py wander
```

Your player character should now start moving and rotating automatically!

## Available Behaviors

```bash
# Wandering behavior (moves and rotates)
uv run python example_control_loop.py wander

# Mining behavior (digs blocks in front)
uv run python example_control_loop.py mine

# Building behavior (places blocks upward)
uv run python example_control_loop.py build
```

## Writing Your Own Control Script

Create a new Python file:

```python
#!/usr/bin/env python3
from agent_client import AgentClient, MoveAction, RotateAction, DigAction
import time

# Connect to bot server
client = AgentClient("http://localhost:8000")

# Send commands
client.send_action(MoveAction("forward", speed=1.0))
time.sleep(2)

client.send_action(RotateAction(yaw_delta=1.57))  # 90 degrees
time.sleep(1)

client.send_action(DigAction())
time.sleep(0.5)

print("Done!")
```

Run it:
```bash
uv run python my_script.py
```

## Troubleshooting

### "HTTP API not available" in Luanti logs

Make sure `config/minetest.conf.template` has:
```ini
secure.http_mods = agent_api
```

Then restart:
```bash
docker compose down
rm -rf data/.minetest/minetest.conf
docker compose up -d
```

### Python can't connect to bot server

Make sure bot_server.py is running and listening on port 8000.

### Agent not responding to commands

1. Verify agent is created: `/agent_list` in game
2. Check bot server is receiving requests: you should see HTTP requests in the bot server logs
3. Enable debug logging: add `agent_api.debug = true` to minetest.conf

### Commands execute but nothing happens

- Make sure you're looking at the right player in-game
- Some actions (like dig/place) require looking at blocks
- Movement requires space to move into

## Next Steps

- Read [API.md](API.md) for complete API documentation
- Check [agent_api/README.md](mods/agent_api/README.md) for Lua API details
- Explore the observation data structures (currently collected but not sent to Python)
- Build more complex behaviors using the action API

## Configuration Reference

### Luanti Server (`config/minetest.conf.template`)

```ini
# Agent API
agent_api.bot_server_url = http://host.docker.internal:8000
agent_api.poll_interval = 0.2
agent_api.agent_name = AIAgent
agent_api.auto_create = false
agent_api.debug = false

# Security (required)
secure.enable_security = true
secure.trusted_mods = agent_api
secure.http_mods = agent_api
```

### World Configuration (`config/world.mt.template`)

```ini
load_mod_agent_api = true
```

## Docker Configuration

The mod is automatically mounted via `docker-compose.yml`:

```yaml
volumes:
  - ./mods:/config/.minetest/mods:ro
```

## Clean Up

Stop everything:
```bash
# Stop Python bot server: Ctrl+C in its terminal
# Stop control script: Ctrl+C in its terminal

# Stop Luanti server
docker compose down
```

Reset world (optional):
```bash
rm -rf data/.minetest/worlds/world
docker compose up -d
```

## Support

- See [README.md](README.md) for overview
- See [API.md](API.md) for detailed API reference
- Check GitHub issues for known problems

Enjoy experimenting with AI agents in Luanti!
