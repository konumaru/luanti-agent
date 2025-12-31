# Agent API Mod

Luanti-native API for AI agent control and observation.

## Features

### Agent Management
- Create/remove agent entities
- Track multiple agents simultaneously
- Agent lifecycle management

### Observation API
- **Position & Orientation**: Get agent's current position, yaw, pitch, and look direction
- **Surrounding Blocks**: Query blocks in a radius around the agent
- **Nearby Entities**: Detect nearby entities and players
- **Vision System**: Raycast-based look target detection

### Action API
- **Movement**: Move forward, backward, left, right, up, down
- **Rotation**: Relative rotation (delta) or absolute look direction
- **Dig**: Mine/break blocks at look target
- **Place**: Place blocks at look target
- **Use**: Interact with objects (placeholder for extension)

### Communication Layer
- HTTP-based communication with Python server
- Automatic polling for action commands
- Observation data collection

## Configuration

Add to `minetest.conf`:

```ini
# Agent API Configuration
agent_api.bot_server_url = http://host.docker.internal:8000
agent_api.poll_interval = 0.2
agent_api.agent_name = AIAgent
agent_api.debug = false

# Security settings (required for HTTP)
secure.http_mods = agent_api
```

## Usage

### Chat Commands

```
/agent_create [name]    - Create a new AI agent
/agent_remove <name>    - Remove an agent
/agent_list             - List all active agents
```

Requires `server` privilege.

### Lua API

```lua
-- Create an agent
local agent = agent_api.create_agent({x=0, y=10, z=0}, "MyAgent")

-- Get observations
local obs = agent_api.observe(agent)
-- obs contains: position, orientation, surrounding_blocks, 
--               nearby_entities, look_target, health, state

-- Execute actions
agent_api.execute_action(agent, {
    type = "move",
    direction = "forward",
    speed = 1.0
})

agent_api.execute_action(agent, {
    type = "rotate",
    yaw_delta = 0.1,
    pitch_delta = 0
})

agent_api.execute_action(agent, {
    type = "dig"
})

agent_api.execute_action(agent, {
    type = "place",
    node_name = "default:dirt"
})
```

## Python Integration

The mod automatically polls a Python server for commands. See the `agent/` directory for Python client implementation.

## Architecture

```
┌─────────────┐         HTTP          ┌──────────────┐
│   Luanti    │ ◄─────────────────► │    Python    │
│  (Lua Mod)  │   Poll /next         │    Server    │
│             │   Send observations  │              │
└─────────────┘                       └──────────────┘
      │
      ▼
 Observe → Act Loop
```

## License

See project LICENSE.
