#!/bin/bash
set -euo pipefail

DATA_DIR="${DATA_DIR:-}"
if [ -z "$DATA_DIR" ]; then
    if [ -d "/config" ]; then
        DATA_DIR="/config/.minetest"
    else
        DATA_DIR="/root/.minetest"
    fi
fi

CONFIG_DIR="${CONFIG_DIR:-/config-static}"
WORLD_DIR="$DATA_DIR/worlds/world"
WORLD_MT_FILE="$WORLD_DIR/world.mt"
CONFIG_WORLD_MT="$CONFIG_DIR/world.mt"
CONF_FILE="${CONF_FILE:-$DATA_DIR/minetest.conf}"
GAMES_DIR="$DATA_DIR/games"

read_world_setting() {
    local key="$1"
    local file="$2"

    awk -F= -v k="$key" '
        $0 ~ "^[[:space:]]*" k "[[:space:]]*=" {
            value=$2
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            print value
            exit
        }
    ' "$file"
}

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
echo "Config path: $CONF_FILE"
echo "World config source: $CONFIG_WORLD_MT"
echo "World directory: $WORLD_DIR"

if [ ! -f "$CONF_FILE" ]; then
    echo "Error: minetest.conf not found at $CONF_FILE"
    exit 1
fi

if [ ! -d "$WORLD_DIR" ]; then
    echo "World directory not found; creating..."
    mkdir -p "$WORLD_DIR"
fi

if [ ! -f "$WORLD_MT_FILE" ]; then
    if [ -f "$CONFIG_WORLD_MT" ]; then
        cp "$CONFIG_WORLD_MT" "$WORLD_MT_FILE"
        echo "Copied world.mt from $CONFIG_WORLD_MT"
    else
        echo "Error: world.mt config not found at $CONFIG_WORLD_MT"
        exit 1
    fi
else
    echo "world.mt already exists; leaving as-is"
fi

GAME_ID="$(read_world_setting "gameid" "$WORLD_MT_FILE" || true)"
WORLD_NAME="$(read_world_setting "world_name" "$WORLD_MT_FILE" || true)"

if [ -n "$WORLD_NAME" ]; then
    echo "World name: $WORLD_NAME"
fi

if [ -n "$GAME_ID" ]; then
    if ! [[ "$GAME_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: Invalid gameid in $WORLD_MT_FILE: $GAME_ID"
        echo "gameid must contain only alphanumeric characters, underscores, and hyphens"
        exit 1
    fi
fi

mkdir -p "$GAMES_DIR"

if [ -n "$GAME_ID" ] && [ ! -d "$GAMES_DIR/$GAME_ID" ]; then
    GAME_REPO_URL_DEFAULT=""
    if [ "$GAME_ID" = "voxelibre" ]; then
        GAME_REPO_URL_DEFAULT="https://git.minetest.land/VoxeLibre/VoxeLibre.git"
    fi
    GAME_REPO_URL="${GAME_REPO_URL:-$GAME_REPO_URL_DEFAULT}"
    GAME_REPO_BRANCH="${GAME_REPO_BRANCH:-}"

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

if [ -n "$GAME_ID" ]; then
    FIND_BIOME_INIT="$GAMES_DIR/$GAME_ID/mods/MISC/findbiome/init.lua"
    if [ -f "$FIND_BIOME_INIT" ]; then
        if ! grep -q "compatibility shim for get_mapgen_edges" "$FIND_BIOME_INIT"; then
            echo "Patching findbiome mod for get_mapgen_edges compatibility..."
            tmp_file="$(mktemp)"
            cat > "$tmp_file" <<'PATCH'
-- Compatibility shim for older Luanti versions missing get_mapgen_edges
if not minetest.get_mapgen_edges then
  local function get_mapgen_edges_fallback()
    local limit = tonumber(minetest.get_mapgen_setting("mapgen_limit")) or 31000
    return {x = -limit, y = -limit, z = -limit}, {x = limit, y = limit, z = limit}
  end
  minetest.get_mapgen_edges = get_mapgen_edges_fallback
end

PATCH
            cat "$FIND_BIOME_INIT" >> "$tmp_file"
            cat "$tmp_file" > "$FIND_BIOME_INIT"
            rm -f "$tmp_file"
        fi
    fi
fi

echo "=== World initialization complete ==="
