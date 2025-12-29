#!/bin/bash
set -euo pipefail

# World Initialization Script for Luanti AI Agent Experiments
# This script initializes a reproducible world with fixed seed and configuration

DATA_DIR="${DATA_DIR:-/data}"
WORLD_NAME="${WORLD_NAME:-world}"
WORLD_DIR="$DATA_DIR/worlds/$WORLD_NAME"
CONF_FILE="$DATA_DIR/minetest.conf"
WORLD_MT_FILE="$WORLD_DIR/world.mt"
MODS_DIR="$DATA_DIR/mods"
GAMES_DIR="$DATA_DIR/games"
FIXED_SEED="${FIXED_SEED:-12345678}"
GAME_ID="${GAME_ID:-mineclone2}"

# Validate GAME_ID contains only safe characters
if ! [[ "$GAME_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Invalid GAME_ID: $GAME_ID"
    echo "GAME_ID must contain only alphanumeric characters, underscores, and hyphens"
    exit 1
fi

# Template files
CONF_TEMPLATE="/config/minetest.conf.template"
WORLD_MT_TEMPLATE="/config/world.mt.template"

echo "=== Luanti World Initialization ==="
echo "Data directory: $DATA_DIR"
echo "World name: $WORLD_NAME"
echo "World directory: $WORLD_DIR"
echo "Fixed seed: $FIXED_SEED"
echo ""

# Create directories
mkdir -p "$WORLD_DIR"
mkdir -p "$MODS_DIR"
mkdir -p "$GAMES_DIR"

# Download and setup games
echo ""
if [ -f "/scripts/download-games.sh" ]; then
    echo "Running game download script..."
    GAMES_DIR="$GAMES_DIR" /scripts/download-games.sh
else
    echo "Game download script not found, skipping game setup..."
fi
echo ""

# Initialize minetest.conf
if [ ! -f "$CONF_FILE" ]; then
    echo "Creating minetest.conf from template..."
    if [ -f "$CONF_TEMPLATE" ]; then
        # Copy template and replace seed placeholder
        sed "s/fixed_map_seed = 12345678/fixed_map_seed = $FIXED_SEED/" "$CONF_TEMPLATE" > "$CONF_FILE"
        echo "  minetest.conf created successfully"
    else
        echo "  Warning: Template not found at $CONF_TEMPLATE"
        echo "  Creating basic configuration..."
        cat > "$CONF_FILE" <<EOF
# Auto-generated basic configuration
port = 30000
server_name = Luanti AI Agent Server
server_announce = false
enable_damage = true
creative_mode = false
fixed_map_seed = $FIXED_SEED
EOF
    fi
else
    echo "minetest.conf already exists, skipping..."
fi

# Initialize world.mt
if [ ! -f "$WORLD_MT_FILE" ]; then
    echo "Creating world.mt from template..."
    if [ -f "$WORLD_MT_TEMPLATE" ]; then
        cp "$WORLD_MT_TEMPLATE" "$WORLD_MT_FILE"
        echo "  world.mt created successfully"
    else
        echo "  Warning: Template not found at $WORLD_MT_TEMPLATE"
        echo "  Creating basic world.mt..."
        cat > "$WORLD_MT_FILE" <<EOF
enable_damage = true
creative_mode = false
mod_storage_backend = sqlite3
auth_backend = sqlite3
player_backend = sqlite3
backend = sqlite3
gameid = $GAME_ID
world_name = $WORLD_NAME
load_mod_python_bot = true
EOF
    fi
else
    echo "world.mt already exists, skipping..."
fi

# Download and setup mods
echo ""
if [ -f "/scripts/download-mods.sh" ]; then
    echo "Running mod download script..."
    MODS_DIR="$MODS_DIR" /scripts/download-mods.sh
else
    echo "Mod download script not found, skipping mod setup..."
fi

echo ""
echo "=== World initialization complete ==="
echo ""
echo "World configuration:"
echo "  World directory: $WORLD_DIR"
echo "  Game ID: $GAME_ID"
echo "  Fixed seed: $FIXED_SEED"
echo "  Damage enabled: true"
echo "  Creative mode: false"
echo ""
echo "Installed mods:"
if [ -d "$MODS_DIR" ]; then
    ls -1 "$MODS_DIR" | sed 's/^/  - /'
else
    echo "  (none)"
fi
echo ""
