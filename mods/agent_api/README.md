# Agent API Mod

Luanti-native API for AI agent control and observation.

## Features

### Agent Management
- Create/remove agent entities
- Track multiple agents simultaneously
- Agent lifecycle management
- Living agents (demo NPC) with hunger/fatigue state and simple rule-based behavior
- Debug spawn utility for multiple demo agents

### Observation API
- **Position & Orientation**: Get agent's current position, yaw, pitch, and look direction
- **Surrounding Blocks**: Query blocks in a radius around the agent
- **Visibility Filtering**: Optional filtering of occluded (underground) blocks
- **Nearby Entities**: Detect nearby entities and players
- **Vision System**: Raycast-based look target detection

### Action API
- **Movement**: Move forward, backward, left, right, up, down
- **Rotation**: Relative rotation (delta) or absolute look direction
- **Dig**: Mine/break blocks at look target
- **Place**: Place blocks at look target
- **Use**: Interact with objects (placeholder for extension)
- **Observation Options**: Configure visibility filtering
- **Chat**: Send messages in game chat

### Communication Layer
- HTTP-based communication with Python server
- Automatic polling for action commands
- Observation data collection

## Configuration

Add to `minetest.conf`:

```ini
# Agent API Configuration
agent_api.bot_server_url = http://bot:8000
agent_api.poll_interval = 0.2
agent_api.agent_name = AIAgent
agent_api.debug = false
agent_api.debug_spawn = false        # If true, spawn demo living agents near joining player
agent_api.debug_spawn_count = 3      # Number of living agents to spawn in debug mode
agent_api.living_seed = 0xBEEFFEED   # Optional seed override for deterministic living agent movement
agent_api.living_visual = auto       # auto (default), character, or cube
agent_api.living_use_skinsdb = true  # If skinsdb/skins is available, pick random textures
agent_api.living_mesh = character.b3d  # default: skinsdb_3d_armor_character_5.b3d when skinsdb is enabled
agent_api.living_default_texture = unknown_node.png

# Security settings (required for HTTP)
secure.http_mods = agent_api
```

If you run the bot server on your host, set `agent_api.bot_server_url = http://host.docker.internal:8000`.

## Usage

### Chat Commands

```
/agent_create           - Create AI agent control for yourself
/agent_attach <player>  - Attach agent to another player (requires server privilege)
/agent_remove [player]  - Remove agent control from player (defaults to self)
/agent_list             - List all active agents
/agent_spawn_debug [n]  - Spawn n living agents near you (default from config)
/switch_agent           - Alias of /agent_create
```

### Lua API

```lua
-- Attach agent control to an existing player
local agent = agent_api.create_agent("PlayerName")

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

-- New: Set observation options
agent_api.execute_action(agent, {
    type = "set_observation_options",
    options = {
        filter_occluded_blocks = true  -- Only see visible blocks
    }
})

-- New: Send chat message
agent_api.execute_action(agent, {
    type = "chat",
    message = "Hello from Lua!"
})
```

## Character skins (skinsdb)

With `skinsdb` enabled, the demo living agents will use a character mesh and can pick a random skin texture.

When you spawn them via `/agent_spawn_debug`, they will try to inherit your current player `mesh` + `textures`
so they look like a real character (often exactly your skin), even in games that don't ship `character.b3d`.

If you prefer to force a mode regardless of installed mods, set `agent_api.living_visual = character` or
`agent_api.living_visual = cube` in `minetest.conf`.

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
