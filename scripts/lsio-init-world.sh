#!/usr/bin/with-contenv bash
set -euo pipefail

: "${DATA_DIR:=/config/.minetest}"
: "${TEMPLATE_DIR:=/config-templates}"
: "${PUID:=}"
: "${PGID:=}"

export DATA_DIR TEMPLATE_DIR

/scripts/init-world.sh

if [ -n "$PUID" ] && [ -n "$PGID" ] && [ -d "$DATA_DIR" ]; then
    echo "Setting ownership for $DATA_DIR to ${PUID}:${PGID}..."
    chown -R "$PUID:$PGID" "$DATA_DIR"
fi

exit 0
