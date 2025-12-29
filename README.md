# luanti-agent

Luanti (Minetest) server with AI agent experiments - automatic world initialization and reproducible setup.

## Overview

This project provides a Dockerized Luanti server designed for AI agent experiments with:

- **Reproducible worlds**: Fixed seed ensures identical world generation
- **Automatic initialization**: World and mods are set up automatically on first run
- **Zero manual configuration**: Just run `docker compose up` and you're ready
- **Customizable**: Easy to add mods and adjust settings

## Quick Start

```bash
# Clone the repository
git clone https://github.com/konumaru/luanti-agent.git
cd luanti-agent

# Start the server (builds and initializes automatically)
docker compose up -d

# View logs
docker compose logs -f

# Stop the server
docker compose down
```

The server will be available at `localhost:30000` (UDP).

## World Initialization

### Automatic Setup

On first run, the initialization script (`scripts/init-world.sh`) automatically:

1. Downloads and installs MineClone2 game (requires network access)
2. Creates the world directory structure
3. Copies configuration from templates
4. Sets fixed map seed (12345678) for reproducibility
5. Downloads and installs mods (if configured)
6. Configures game settings (damage, creative mode, etc.)

**Note**: MineClone2 is downloaded from the official Git repository on first startup. If running in an offline environment or if the download fails, you can manually place the MineClone2 game files in `data/games/mineclone2/`.

### Configuration Templates

Templates are located in the `config/` directory:

- **`config/minetest.conf.template`**: Server and world generation settings
- **`config/world.mt.template`**: World metadata and mod loading configuration

### World Settings

Default configuration:

- **Game ID**: mineclone2 (Minecraft-like game for Minetest)
- **Map Seed**: 12345678 (fixed for reproducibility)
- **Map Generator**: v7 (with caves, dungeons, decorations)
- **Damage**: Enabled
- **Creative Mode**: Disabled
- **Time Speed**: 72x normal speed

### Customizing the World

#### Changing the Seed

You can set a custom seed using the `FIXED_SEED` environment variable:

```yaml
# In docker-compose.yml
services:
  luanti:
    environment:
      - WORLD_NAME=world
      - GAME_ID=mineclone2
      - FIXED_SEED=98765432
```

Or via command line:

```bash
docker compose run -e FIXED_SEED=98765432 luanti
```

#### Other Customizations

To customize other world settings:

1. Edit `config/minetest.conf.template` before building
2. Rebuild the Docker image: `docker compose build`
3. Remove existing world data: `rm -rf data/worlds/world/*.sqlite data/worlds/world/*.txt`
4. Start the server: `docker compose up -d`

## Mod Management

### Adding Mods

Mods can be added by editing `scripts/download-mods.sh`:

```bash
# Example: Add mob mods from ContentDB
download_contentdb_mod "mobs_redo" "TenPlus1"
download_contentdb_mod "mobs_animal" "TenPlus1"
download_contentdb_mod "mobs_monster" "TenPlus1"

# Example: Add mods from GitHub
download_github_mod "worldedit" "https://github.com/Uberi/Minetest-WorldEdit.git" "master"
```

After editing:

1. Rebuild: `docker compose build`
2. Restart: `docker compose up -d`

### Enabling Mods

To enable downloaded mods, edit `config/world.mt.template`:

```
load_mod_mobname = true
load_mod_worldedit = true
```

### Currently Included Mods

- **python_bot**: HTTP-controlled bot for AI agent experiments (in `data/mods/python_bot/`)

## Game Management

### Changing Games

The default game is MineClone2. To use a different game:

1. Edit `docker-compose.yml` and change `GAME_ID`:
   ```yaml
   environment:
     - GAME_ID=minetest_game  # or another game
   ```

2. Edit `scripts/download-games.sh` to download your preferred game

3. Update `config/world.mt.template` to set the correct `gameid`

### Manual Game Installation

If automatic download fails or you're in an offline environment:

1. Download MineClone2 manually from https://git.minetest.land/MineClone2/MineClone2
2. Extract it to `data/games/mineclone2/`
3. Ensure the directory contains `game.conf` and `mods/` subdirectory
4. Start the server: `docker compose up -d`

## Project Structure

```
.
├── config/
│   ├── minetest.conf.template    # Server configuration template
│   └── world.mt.template          # World metadata template
├── scripts/
│   ├── init-world.sh              # World initialization script
│   ├── download-mods.sh           # Mod download/management script
│   └── download-games.sh          # Game download/management script
├── data/
│   ├── mods/                      # Installed mods
│   ├── worlds/                    # World data (generated)
│   ├── games/                     # Game definitions (mineclone2)
│   └── minetest.conf              # Active server config (generated)
├── agent/                         # AI agent Python code
├── Dockerfile                     # Custom Luanti server image
├── docker-compose.yml             # Docker Compose configuration
└── docker-entrypoint.sh           # Container entry point script
```
```

## Development

### Rebuilding the World

To start with a fresh world (same seed, clean state):

```bash
# Stop the server
docker compose down

# Remove world data (keeps config and mods)
rm -rf data/worlds/world/*.sqlite data/worlds/world/*.txt data/worlds/world/*.png

# Restart
docker compose up -d
```

### Changing the Seed

1. Edit `config/minetest.conf.template`
2. Change the `fixed_map_seed` value
3. Follow "Rebuilding the World" steps above

### Testing Initialization

To test the initialization without running the server:

```bash
docker compose build
docker compose run --rm luanti /scripts/init-world.sh
```

## AI Agent Integration

The server includes the `python_bot` mod configured to communicate with an AI agent via HTTP:

- **Endpoint**: `http://host.docker.internal:8000/next`
- **Poll Interval**: 0.2 seconds
- **Bot Name**: PyBot

See `agent/` directory for the Python agent implementation.

## Acceptance Criteria ✓

- [x] New environment: `docker compose up` creates identical world
- [x] Zero manual configuration required
- [x] Mods and settings applied automatically
- [x] Fixed seed ensures reproducibility
- [x] Easy to customize and extend

## Notes

- This is designed for **experimental/development use**
- World data (SQLite databases, player data) is excluded from git
- The `mineclone2` game is used by default (Minecraft-like experience)
- MineClone2 is automatically downloaded from ContentDB on first run
- Mods can be added without modifying core files

## License

See LICENSE file for details.
