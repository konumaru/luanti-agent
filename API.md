# Agent API Documentation

Complete documentation for the Luanti Agent Control & Observation API.

## Overview

The Agent API provides a Luanti-native interface for AI agent control and observation, designed to enable Python-based AI agents to interact with the Luanti world through a minimal observe → act control loop.

## Architecture

### Communication Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        Python Process                             │
│  ┌──────────────┐        ┌──────────────┐                       │
│  │ agent_client │───────▶│ bot_server   │                       │
│  │              │        │ (HTTP:8000)  │                       │
│  │ - Actions    │        │ - Queue cmds │                       │
│  │ - Observ.    │        │ - /next      │                       │
│  └──────────────┘        └──────────────┘                       │
└───────────────────────────────┬──────────────────────────────────┘
                                │ HTTP GET /next
                                │ (polling)
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Luanti Server                              │
│  ┌──────────────────────────────────────────────────┐           │
│  │                  agent_api Mod (Lua)              │           │
│  │                                                    │           │
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────┐ │           │
│  │  │   Agent     │  │  Observation │  │ Action  │ │           │
│  │  │ Management  │─▶│     API      │  │   API   │ │           │
│  │  │             │  │              │  │         │ │           │
│  │  │ - create    │  │ - position   │  │ - move  │ │           │
│  │  │ - remove    │  │ - blocks     │  │ - dig   │ │           │
│  │  │ - registry  │  │ - entities   │  │ - place │ │           │
│  │  └─────────────┘  └──────────────┘  └─────────┘ │           │
│  │                           │                       │           │
│  │                           ▼                       │           │
│  │                  ┌──────────────┐                │           │
│  │                  │ Control Loop │                │           │
│  │                  │ (globalstep) │                │           │
│  │                  └──────────────┘                │           │
│  └──────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

## Lua API Reference

### Agent Management

#### `agent_api.create_agent(player_name)`

Attach agent control to an existing player.

**Parameters:**
- `player_name` (string): Name of the player to control

**Returns:**
- Agent object or `nil` on failure

**Example:**
```lua
local agent = agent_api.create_agent("PlayerName")
```

**Note:** The player must be online for this to work. Agents are automatically
cleaned up when players leave the server.

#### `agent_api.get_agent(name)`

Get an agent by name.

**Parameters:**
- `name` (string): Agent name

**Returns:**
- Agent object or `nil`

#### `agent_api.remove_agent(name)`

Remove an agent.

**Parameters:**
- `name` (string): Agent name

**Returns:**
- `true` if successful, `false` otherwise

### Observation API

#### `agent_api.get_position(agent)`

Get agent's current position.

**Returns:**
- Position table `{x, y, z}` or `nil`

#### `agent_api.get_orientation(agent)`

Get agent's orientation.

**Returns:**
```lua
{
    yaw = 0.0,           -- Horizontal angle
    pitch = 0.0,         -- Vertical angle
    look_dir = {x, y, z} -- Normalized direction vector
}
```

#### `agent_api.get_surrounding_blocks(agent, radius)`

Get blocks around the agent.

**Parameters:**
- `radius` (number, optional): Search radius (default: 1)

**Returns:**
- Array of block data:
```lua
{
    {
        pos = {x, y, z},
        name = "default:stone",
        param1 = 0,
        param2 = 0
    },
    ...
}
```

#### `agent_api.get_nearby_entities(agent, radius)`

Get nearby entities.

**Parameters:**
- `radius` (number, optional): Search radius (default: 10)

**Returns:**
- Array of entity data:
```lua
{
    {
        pos = {x, y, z},
        distance = 5.2,
        name = "entity_name",
        type = "entity" or "player",
        player_name = "username" -- only for players
    },
    ...
}
```

#### `agent_api.get_look_target(agent, max_distance)`

Get what the agent is looking at (raycast).

**Parameters:**
- `max_distance` (number, optional): Max raycast distance (default: 5)

**Returns:**
```lua
{
    type = "node" or "object",
    pos = {x, y, z},      -- for nodes
    name = "default:stone",
    distance = 3.5,
    object = obj_ref      -- for objects
}
```

#### `agent_api.observe(agent)`

Collect complete observation data.

**Returns:**
```lua
{
    position = {x, y, z},
    orientation = {...},
    surrounding_blocks = [...],
    nearby_entities = [...],
    look_target = {...},
    health = 20,
    state = "idle"
}
```

### Action API

#### `agent_api.action_move(agent, direction, speed)`

Move agent in a direction.

**Parameters:**
- `direction` (string): "forward", "backward", "left", "right", "up", "down"
- `speed` (number, optional): Movement speed multiplier (default: 1.0)

**Returns:**
- `true` if successful

#### `agent_api.action_rotate(agent, yaw_delta, pitch_delta)`

Rotate agent by delta angles.

**Parameters:**
- `yaw_delta` (number): Change in yaw (radians)
- `pitch_delta` (number): Change in pitch (radians)

**Returns:**
- `true` if successful

#### `agent_api.action_look_at(agent, yaw, pitch)`

Set absolute look direction.

**Parameters:**
- `yaw` (number): Absolute yaw angle (radians)
- `pitch` (number): Absolute pitch angle (radians)

**Returns:**
- `true` if successful

#### `agent_api.action_dig(agent)`

Dig/mine block at look target.

**Returns:**
- `true` if block was dug

#### `agent_api.action_place(agent, node_name)`

Place block at look target.

**Parameters:**
- `node_name` (string, optional): Node to place (default: "default:dirt")

**Returns:**
- `true` if block was placed

#### `agent_api.action_use(agent)`

Use/interact with target (placeholder).

**Returns:**
- `true` if successful

#### `agent_api.action_set_observation_options(agent, options)`

Set observation options for the agent.

**Parameters:**
- `options` (table): Options table
  - `filter_occluded_blocks` (boolean, optional): If true, filter out blocks not visible due to occlusion

**Returns:**
- `true` if successful

**Example:**
```lua
agent_api.action_set_observation_options(agent, {
    filter_occluded_blocks = true
})
```

#### `agent_api.action_chat(agent, message)`

Send a chat message in the game.

**Parameters:**
- `message` (string): Message to send

**Returns:**
- `true` if successful

**Example:**
```lua
agent_api.action_chat(agent, "Hello, world!")
```

#### `agent_api.execute_action(agent, action)`

Execute an action command.

**Parameters:**
- `action` (table): Action descriptor

**Action Format:**
```lua
-- Move
{type = "move", direction = "forward", speed = 1.0}

-- Rotate
{type = "rotate", yaw_delta = 0.1, pitch_delta = 0}

-- Look at
{type = "look_at", yaw = 1.57, pitch = 0}

-- Dig
{type = "dig"}

-- Place
{type = "place", node_name = "default:stone"}

-- Use
{type = "use"}

-- Set observation options
{type = "set_observation_options", options = {filter_occluded_blocks = true}}

-- Chat
{type = "chat", message = "Hello!"}
```

### Chat Commands

```
/agent_create           - Create AI agent control for yourself
/agent_attach <player>  - Attach agent to another player (requires server privilege)
/agent_remove [player]  - Remove agent control from player (defaults to self)
/agent_list             - List all active agents
```

## Python API Reference

### Classes

#### `Position(x, y, z)`

3D position data class.

#### `Orientation(yaw, pitch, look_dir)`

Agent orientation data class.

#### `Block(pos, name, param1, param2)`

Block information data class.

#### `Entity(pos, distance, name, entity_type, player_name)`

Entity information data class.

#### `LookTarget(target_type, distance, pos, name)`

Look target data class.

#### `Observation(position, orientation, surrounding_blocks, nearby_entities, look_target, health, state)`

Complete observation data class.

### Actions

#### `MoveAction(direction, speed=1.0)`

Create a movement action.

**Parameters:**
- `direction`: "forward", "backward", "left", "right", "up", "down"
- `speed`: Speed multiplier

#### `RotateAction(yaw_delta=None, pitch_delta=None)`

Create a rotation action.

#### `LookAtAction(yaw=None, pitch=None)`

Create an absolute look direction action.

#### `DigAction()`

Create a dig action.

#### `PlaceAction(node_name="default:dirt")`

Create a place action.

#### `UseAction()`

Create a use action.

#### `SetObservationOptionsAction(filter_occluded_blocks=None)`

Create an action to set observation options.

**Parameters:**
- `filter_occluded_blocks`: If True, filter out blocks not visible due to occlusion; if False, see all blocks

**Example:**
```python
# Enable filtering (realistic vision)
SetObservationOptionsAction(filter_occluded_blocks=True)

# Disable filtering (x-ray vision)
SetObservationOptionsAction(filter_occluded_blocks=False)
```

#### `ChatAction(message)`

Create a chat action.

**Parameters:**
- `message`: The message to send in chat

**Example:**
```python
ChatAction("Hello from the AI agent!")
```

### AgentClient

#### `AgentClient(server_url="http://localhost:8000")`

Create an agent client.

#### `client.send_action(action: Action) -> bool`

Send a single action to the agent.

#### `client.send_actions(actions: List[Action]) -> bool`

Send multiple actions to the agent.

#### `client.get_observation() -> Optional[Observation]`

Get the latest observation (when implemented).

## Configuration

### Luanti Server (`minetest.conf`)

```ini
# Security - Required for HTTP
secure.enable_security = true
secure.trusted_mods = agent_api
secure.http_mods = agent_api

# Agent API
agent_api.bot_server_url = http://host.docker.internal:8000
agent_api.poll_interval = 0.2
agent_api.agent_name = AIAgent
agent_api.debug = false
```

### World Configuration (`world.mt`)

```ini
load_mod_agent_api = true
```

## Usage Examples

### Python: Simple Control Loop

```python
from agent_client import AgentClient, MoveAction, RotateAction
import time

client = AgentClient()

# Simple wandering behavior
for i in range(10):
    # Move forward
    client.send_action(MoveAction("forward", speed=1.0))
    time.sleep(1)
    
    # Rotate
    client.send_action(RotateAction(yaw_delta=0.5))
    time.sleep(0.5)
```

### Python: Mining Behavior

```python
from agent_client import AgentClient, DigAction, MoveAction
import time

client = AgentClient()

# Mine forward
for i in range(5):
    client.send_action(DigAction())
    time.sleep(0.5)
    client.send_action(MoveAction("forward", speed=0.5))
    time.sleep(0.5)
```

### Lua: Manual Agent Creation

```lua
-- Attach agent control to a player
local agent = agent_api.create_agent("PlayerName")

-- Get observation
local obs = agent_api.observe(agent)
print("Agent position: " .. minetest.pos_to_string(obs.position))

-- Execute action
agent_api.execute_action(agent, {
    type = "move",
    direction = "forward",
    speed = 1.0
})
```

## Design Principles

1. **Minimal Interface**: Observe → Act cycle with minimal data transfer
2. **Intent-Level Actions**: Actions express intent (e.g., "dig") rather than low-level inputs
3. **Luanti-Optimized**: Designed for Luanti's architecture, not a port of mineflayer
4. **Server-Side Logic**: Agent management happens in Lua for efficiency
5. **Extensible**: Easy to add new observations and actions

## Future Extensions

- Path planning API
- Inventory management
- Crafting interface
- Advanced vision (FOV, occlusion)
- Multi-agent coordination
- Event-driven observations (block changes, damage, etc.)

## Troubleshooting

### Agent not responding to commands

1. Check bot_server.py is running: `python bot_server.py`
2. Verify mod is loaded: `/agent_list` in game
3. Check HTTP settings in minetest.conf
4. Enable debug logging: `agent_api.debug = true`

### Cannot create agent

1. Ensure you have `server` privilege
2. Check Luanti server logs for errors
3. Verify mod is properly loaded in world.mt

### Communication errors

1. Verify network connectivity between Luanti and Python
2. Check bot_server_url in configuration
3. Ensure no firewall blocking port 8000

## License

See project LICENSE.
