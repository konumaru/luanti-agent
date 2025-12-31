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

# Start the server (pulls the image and initializes automatically)
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

1. Creates the world directory structure
2. Copies configuration from templates
3. Sets fixed map seed (12345678) for reproducibility
4. Ensures the VoxeLibre game is present (downloaded if missing)
5. Creates mods directory (mods are loaded if present)
6. Configures game settings (damage, creative mode, etc.)

**Note**: VoxeLibre is downloaded on first run into `/config/.minetest/games/voxelibre`. For offline use or different games, place files in `./data/.minetest/games/<gameid>` or set `GAME_REPO_URL`.

For the LinuxServer image, `scripts/lsio-init-world.sh` is mounted into `/custom-cont-init.d` to run initialization at container start.

### Configuration Templates

Templates are located in the `config/` directory:

- **`config/minetest.conf.template`**: Server and world generation settings
- **`config/world.mt.template`**: World metadata and mod loading configuration

### World Settings

Default configuration:

- **Game ID**: voxelibre (VoxeLibre game)
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
      - GAME_ID=voxelibre
      - FIXED_SEED=98765432
```

Or via command line:

```bash
docker compose run -e FIXED_SEED=98765432 luanti
```

#### Other Customizations

To customize other world settings:

1. Edit `config/minetest.conf.template`
2. Stop the container: `docker compose down`
3. Remove `./data/.minetest/minetest.conf` (and `./data/.minetest/worlds/<world>/world.mt` if you want it regenerated)
4. Start the container: `docker compose up -d`

## Mod Management

### Adding Mods

Mods can be added by cloning into `./data/.minetest/mods` on the host (mounted at `/config/.minetest/mods`):

```bash
# Example: Add a mod from Git
git clone --depth 1 https://github.com/Uberi/Minetest-WorldEdit.git ./data/.minetest/mods/worldedit
```

After editing:

1. Restart: `docker compose up -d`

### Enabling Mods

To enable downloaded mods, edit `config/world.mt.template`:

```
load_mod_mobname = true
load_mod_worldedit = true
```

If the world already exists, edit `./data/.minetest/worlds/<world>/world.mt` instead and restart.

### Currently Included Mods

- **python_bot**: HTTP-controlled bot for AI agent experiments (place it in `./data/.minetest/mods/python_bot/`)

## Game Management

### Changing Games

The default game is VoxeLibre. To use a different game:

1. Edit `docker-compose.yml` and change `GAME_ID` to match the game folder name
2. Set `GAME_REPO_URL` (and optionally `GAME_REPO_BRANCH`) if you want auto-download
3. Remove `./data/.minetest/games/<gameid>` if you want a fresh download
4. Restart the container: `docker compose up -d`

### Manual Game Installation

If you're in an offline environment:

1. Place the game files under `./data/.minetest/games/<gameid>`
2. Ensure the directory contains `game.conf` and `mods/`
3. Start the server: `docker compose up -d`

## Project Structure

```
.
├── config/
│   ├── minetest.conf.template    # Server configuration template
│   └── world.mt.template          # World metadata template
├── scripts/
│   ├── init-world.sh              # World initialization script
│   ├── lsio-init-world.sh          # LinuxServer init wrapper
│   ├── download-mods.sh           # Optional legacy helper script
│   └── download-games.sh          # Optional legacy helper script
├── agent/                         # AI agent Python code
├── Dockerfile                     # Optional legacy image build
├── docker-compose.yml             # Docker Compose configuration
└── docker-entrypoint.sh           # Container entry point script
```
Container user data lives on the host in `./data/.minetest` (mounted at `/config/.minetest`).

## Development

### Rebuilding the World

To start with a fresh world (same seed, clean state):

```bash
# Stop the server
docker compose down

# Remove world data
rm -rf ./data/.minetest/worlds/world

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
- The `voxelibre` game is used by default (VoxeLibre)
- VoxeLibre is downloaded on first run (see `GAME_REPO_URL`)
- Mods can be added without modifying core files

If you see permission errors writing to `/config/.minetest`, ensure `./data` is owned by `PUID:PGID` (defaults `1000:1000`):

```bash
sudo chown -R 1000:1000 ./data
```

## License

See LICENSE file for details.
