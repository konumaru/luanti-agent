#!/usr/bin/with-contenv bash
set -euo pipefail

: "${DATA_DIR:=/config/.minetest}"
: "${CONFIG_DIR:=/config-static}"
: "${PUID:=}"
: "${PGID:=}"

export DATA_DIR CONFIG_DIR

/scripts/init-world.sh

if [ -n "$PUID" ] && [ -n "$PGID" ] && [ -d "$DATA_DIR" ]; then
    if [ -w "$DATA_DIR" ]; then
        echo "Setting ownership for $DATA_DIR to ${PUID}:${PGID}..."
        if ! chown -R "$PUID:$PGID" "$DATA_DIR"; then
            echo "Warning: Failed to set ownership for some paths under $DATA_DIR."
        fi
    else
        echo "Skipping ownership for $DATA_DIR (not writable)."
    fi
fi

exit 0
