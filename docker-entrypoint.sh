#!/bin/sh
set -eu

DATA_DIR="/data"
CONF_FILE="$DATA_DIR/minetest.conf"
WORLD_NAME="${WORLD_NAME:-world}"
WORLD_DIR="$DATA_DIR/worlds/$WORLD_NAME"
GAME_ID="${GAME_ID:-minetest}"

mkdir -p "$WORLD_DIR"

if [ ! -f "$CONF_FILE" ]; then
  cat > "$CONF_FILE" <<CONFIG
# Auto-generated on first start.
port = ${SERVER_PORT:-30000}
server_name = ${SERVER_NAME:-Luanti Server}
server_description = ${SERVER_DESCRIPTION:-Luanti server via minetestserver}
server_announce = ${SERVER_ANNOUNCE:-false}
enable_damage = ${ENABLE_DAMAGE:-true}
creative_mode = ${CREATIVE_MODE:-false}
CONFIG
fi

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

exec minetestserver --config "$CONF_FILE" --world "$WORLD_DIR" --gameid "$GAME_ID"
