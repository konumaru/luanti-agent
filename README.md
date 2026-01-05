# luanti-agent

Reproducible Luanti server for agent experiments with native Agent Control & Observation API.

## Quick Links

- **[Quick Start Guide](QUICKSTART.md)** - Get up and running in 5 minutes
- **[API Documentation](API.md)** - Complete API reference
- **[Agent Mod README](mods/agent_api/README.md)** - Lua mod details

## Features

- **Docker-based Luanti server** with reproducible world generation
- **Agent API Lua mod** for AI agent control and observation
- **Python client library** for controlling agents
- **Observe → Act control loop** with minimal interface
- **Extensible architecture** for AI experiments
- **Living agents**: simple rule-based NPCs with hunger/fatigue state, debug spawn support, and optional `skinsdb` character visuals

## Quick start

```bash
git clone https://github.com/konumaru/luanti-agent.git
cd luanti-agent

# Start Luanti + bot server
make up

# (Optional) Run the bot server on your host instead of Docker
cd agent
uv sync  # Install dependencies with uv
uv run python bot_server.py

# In another terminal, run an example agent
uv run python example_control_loop.py wander
```

Server: `localhost:30000/udp`

`make up` starts the FastAPI bot server in Docker. Use the optional step above if you
prefer running the bot server on your host.

## Architecture

```
┌─────────────────┐         HTTP         ┌──────────────────┐
│  Luanti Server  │◄────────────────────▶│  Python Process  │
│   (Lua Mod)     │   Poll commands      │                  │
│  agent_api      │   Send observations  │  bot_server.py   │
│                 │                      │  agent_client.py │
└─────────────────┘                      └──────────────────┘
```

### Components

1. **Luanti Server** (Docker): Game server with agent_api mod
2. **agent_api Mod** (Lua): Server-side agent management, observation, and action execution
3. **bot_server.py** (Python): HTTP server for command queuing
4. **agent_client.py** (Python): Client library for controlling agents
5. **example_control_loop.py** (Python): Example agent behaviors

## Agent API

The Agent API provides:

### Observation

- Position & orientation
- Surrounding blocks (configurable radius)
- Nearby entities
- Vision (raycast-based look target)
- Health & state

### Actions

- Movement (forward, backward, left, right, up, down)
- Rotation (relative or absolute)
- Dig/mine blocks
- Place blocks
- Use/interact

### Communication

- HTTP-based polling from Lua to Python
- Command queue for action sequencing
- Type-safe Python data structures

See [API.md](API.md) for complete documentation.

## Usage

### Creating an Agent

Agents are attached to existing player characters. You have two options:

**Option 1: Manual creation in-game**

1. Join the Luanti server as a player
2. Run `/agent_create` to enable agent control for your character
3. The Python client can now control your player

**Option 2: Auto-creation on join**
Set `agent_api.auto_create = true` in `config/minetest.conf` to automatically
create an agent when a player named `agent_api.agent_name` joins.

**Chat Commands:**

```
/agent_create           - Enable agent control for yourself
/agent_attach <player>  - Attach agent to another player (requires server privilege)
/agent_remove [player]  - Disable agent control (defaults to self)
/agent_list             - List all active agents
/agent_spawn_debug [n]  - Spawn demo living agents near you (default count from config)
/switch_agent           - Alias of /agent_create
```

### Current Implementation Status

✅ **Implemented:**

- Complete action API (movement, rotation, dig, place, use)
- Observation collection in Lua (position, orientation, blocks, entities, vision)
- HTTP-based command polling from Lua to Python
- Example control behaviors

⚠️ **Planned for future enhancement:**

- Observation pushing from Lua to Python (currently observations are collected but not sent)
- WebSocket communication for real-time bidirectional data
- Advanced interaction logic (right-click, punch, item use)
- Path planning and high-level behaviors

The current implementation provides a solid foundation for action-based control.
Observation feedback will be added in future updates.

### Example Behaviors

```bash
# Wandering agent
uv run python example_control_loop.py wander

# Mining agent
uv run python example_control_loop.py mine

# Building agent
uv run python example_control_loop.py build
```

## Configuration

### Configuration

Add to `config/minetest.conf`:

```ini
agent_api.bot_server_url = http://bot:8000
agent_api.poll_interval = 0.2
agent_api.agent_name = AIAgent
agent_api.auto_create = false
agent_api.debug = false
```

### Security Settings

Required for HTTP communication:

```ini
secure.enable_security = true
secure.trusted_mods = agent_api
secure.http_mods = agent_api
```

## Python Control

Once an agent is created in-game, you can control it from Python:

```python
from agent_client import AgentClient, MoveAction

client = AgentClient("http://localhost:8000")
client.send_action(MoveAction("forward", speed=1.0))
```

## Data and init

- Data dir: `./data` (minetest data lives under `./data/.minetest`)
- Config: `config/minetest.conf`, `config/world.mt`
- Init: `scripts/init-world.sh` runs at container start via `/custom-cont-init.d`
- World init: copies `config/world.mt` into `./data/.minetest/worlds/world/world.mt`, and keeps it in sync as long as it hasn't been manually customized
- Bot server URL: edit `config/minetest.conf`
  - If you run the bot server on your host, set `agent_api.bot_server_url = http://host.docker.internal:8000`

## Common tasks

### Change seed

- Edit `config/minetest.conf`, then `make restart`

### Add mods

- Place mods in `./data/.minetest/mods`
- Enable in `config/world.mt` (new worlds) or `./data/.minetest/worlds/world/world.mt` (existing)
- Apply to existing world: `make reset-config` then `make restart`

#### Optional: skinsdb (character skins)

- `skinsdb` depends on `player_api` (both are included under `./mods/` and also auto-downloaded by `scripts/init-world.sh` if missing)
- Enabled by default in `config/world.mt` (`load_mod_player_api = true`, `load_mod_skinsdb = true`)
- The demo living agents render as a character mesh and pick a random skin when available
- To re-download/upgrade: delete `./mods/player_api` and/or `./mods/skinsdb`, then `make restart`

### Change game

- Edit `gameid` in `config/world.mt`
- Remove `./data/.minetest/games/<gameid>` to re-download
- Apply to existing world: `make reset-config` (or `make reset-world` for a clean world)
- Restart: `make restart`

### Reset world

```bash
make reset-world
```

## Permissions

If you see permission errors writing to `/config/.minetest`:

```bash
sudo chown -R 1000:1000 ./data
```

Match `PUID/PGID` in `docker-compose.yml`.

## License

See LICENSE.
