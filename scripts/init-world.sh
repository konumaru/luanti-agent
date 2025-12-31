#!/bin/bash
set -euo pipefail

# World Initialization Script for Luanti AI Agent Experiments
# This script initializes a reproducible world with fixed seed and configuration

DATA_DIR="${DATA_DIR:-}"
if [ -z "$DATA_DIR" ]; then
    if [ -d "/config" ]; then
        DATA_DIR="/config/.minetest"
    else
        DATA_DIR="/root/.minetest"
    fi
fi
WORLD_NAME="${WORLD_NAME:-world}"
WORLD_DIR="$DATA_DIR/worlds/$WORLD_NAME"
CONF_FILE="$DATA_DIR/minetest.conf"
WORLD_MT_FILE="$WORLD_DIR/world.mt"
MODS_DIR="$DATA_DIR/mods"
GAMES_DIR="$DATA_DIR/games"
FIXED_SEED="${FIXED_SEED:-12345678}"
GAME_ID="${GAME_ID:-voxelibre}"
GAME_REPO_URL_DEFAULT=""
if [ "$GAME_ID" = "voxelibre" ]; then
    GAME_REPO_URL_DEFAULT="https://git.minetest.land/VoxeLibre/VoxeLibre.git"
fi
GAME_REPO_URL="${GAME_REPO_URL:-$GAME_REPO_URL_DEFAULT}"
GAME_REPO_BRANCH="${GAME_REPO_BRANCH:-}"

# Validate GAME_ID contains only safe characters
if ! [[ "$GAME_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Invalid GAME_ID: $GAME_ID"
    echo "GAME_ID must contain only alphanumeric characters, underscores, and hyphens"
    exit 1
fi

# Template files
TEMPLATE_DIR="${TEMPLATE_DIR:-/config}"
if [ ! -f "$TEMPLATE_DIR/minetest.conf.template" ] && [ -f "/config-templates/minetest.conf.template" ]; then
    TEMPLATE_DIR="/config-templates"
fi
CONF_TEMPLATE="$TEMPLATE_DIR/minetest.conf.template"
WORLD_MT_TEMPLATE="$TEMPLATE_DIR/world.mt.template"

download_file() {
    local url="$1"
    local output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fL "$url" -o "$output"
        return
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -qO "$output" "$url"
        return
    fi

    echo "Error: curl or wget is required to download $url"
    return 1
}

download_game_archive() {
    local repo_url="$1"
    local dest_dir="$2"
    shift 2
    local branches=("$@")
    local repo_base="${repo_url%.git}"
    local tmp_dir
    local branch

    if [ "${#branches[@]}" -eq 0 ]; then
        branches=("master" "main")
    fi

    tmp_dir="$(mktemp -d)"
    for branch in "${branches[@]}"; do
        if download_file "${repo_base}/archive/${branch}.tar.gz" "$tmp_dir/game.tar.gz"; then
            if ! command -v tar >/dev/null 2>&1; then
                echo "Error: tar is required to extract ${branch}.tar.gz"
                rm -rf "$tmp_dir"
                return 1
            fi
            tar -xzf "$tmp_dir/game.tar.gz" -C "$tmp_dir"
            break
        fi
        if download_file "${repo_base}/archive/${branch}.zip" "$tmp_dir/game.zip"; then
            if ! command -v unzip >/dev/null 2>&1; then
                echo "Error: unzip is required to extract ${branch}.zip"
                rm -rf "$tmp_dir"
                return 1
            fi
            unzip -q "$tmp_dir/game.zip" -d "$tmp_dir"
            break
        fi
    done

    local game_conf
    game_conf="$(find "$tmp_dir" -maxdepth 3 -type f -name "game.conf" | head -n 1 || true)"
    if [ -z "$game_conf" ]; then
        echo "Error: Could not find game.conf in downloaded archive"
        rm -rf "$tmp_dir"
        return 1
    fi

    local extracted_dir
    extracted_dir="$(dirname "$game_conf")"
    mv "$extracted_dir" "$dest_dir"
    rm -rf "$tmp_dir"
}

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

# Ensure the game is present
if [ ! -d "$GAMES_DIR/$GAME_ID" ]; then
    if [ -n "$GAME_REPO_URL" ]; then
        echo "Game '$GAME_ID' not found; downloading from $GAME_REPO_URL..."
        if command -v git >/dev/null 2>&1; then
            if [ -n "$GAME_REPO_BRANCH" ]; then
                git clone --depth 1 --branch "$GAME_REPO_BRANCH" "$GAME_REPO_URL" "$GAMES_DIR/$GAME_ID"
            else
                git clone --depth 1 "$GAME_REPO_URL" "$GAMES_DIR/$GAME_ID"
            fi
            rm -rf "$GAMES_DIR/$GAME_ID/.git"
        else
            if [ -n "$GAME_REPO_BRANCH" ]; then
                download_game_archive "$GAME_REPO_URL" "$GAMES_DIR/$GAME_ID" "$GAME_REPO_BRANCH"
            else
                download_game_archive "$GAME_REPO_URL" "$GAMES_DIR/$GAME_ID"
            fi
        fi
    else
        echo "Warning: Game '$GAME_ID' not found in $GAMES_DIR"
        echo "Set GAME_REPO_URL or place the game at $GAMES_DIR/$GAME_ID"
    fi
fi

# Patch VoxeLibre findbiome mod for older Luanti versions missing get_mapgen_edges.
FIND_BIOME_INIT="$GAMES_DIR/$GAME_ID/mods/MISC/findbiome/init.lua"
if [ -f "$FIND_BIOME_INIT" ]; then
    if ! grep -q "compatibility shim for get_mapgen_edges" "$FIND_BIOME_INIT"; then
        echo "Patching findbiome mod for get_mapgen_edges compatibility..."
        tmp_file="$(mktemp)"
        cat > "$tmp_file" <<'EOF'
-- Compatibility shim for older Luanti versions missing get_mapgen_edges
if not minetest.get_mapgen_edges then
  local function get_mapgen_edges_fallback()
    local limit = tonumber(minetest.get_mapgen_setting("mapgen_limit")) or 31000
    return {x = -limit, y = -limit, z = -limit}, {x = limit, y = limit, z = limit}
  end
  minetest.get_mapgen_edges = get_mapgen_edges_fallback
end

EOF
        cat "$FIND_BIOME_INIT" >> "$tmp_file"
        cat "$tmp_file" > "$FIND_BIOME_INIT"
        rm -f "$tmp_file"
    fi
fi

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
        sed -e "s/^gameid = .*/gameid = $GAME_ID/" \
            -e "s/^world_name = .*/world_name = $WORLD_NAME/" \
            "$WORLD_MT_TEMPLATE" > "$WORLD_MT_FILE"
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
