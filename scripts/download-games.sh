#!/bin/bash
set -euo pipefail

# Game Download and Management Script
# This script downloads and configures games for the Luanti server

GAMES_DIR="${GAMES_DIR:-/data/games}"
TEMP_DIR="/tmp/luanti-games"

echo "=== Luanti Game Download Script ==="
echo "Games directory: $GAMES_DIR"

# Create games directory if it doesn't exist
mkdir -p "$GAMES_DIR"
mkdir -p "$TEMP_DIR"

# Function to download a game from ContentDB
download_contentdb_game() {
    local game_name="$1"
    local author="$2"
    local release_id="${3:-}"
    
    # Validate parameters contain only safe characters
    if ! [[ "$game_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "  Error: Invalid game name: $game_name"
        return 1
    fi
    if ! [[ "$author" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "  Error: Invalid author name: $author"
        return 1
    fi
    
    if [ -n "$release_id" ] && ! [[ "$release_id" =~ ^[0-9]+$ ]]; then
        echo "  Error: Invalid release id: $release_id"
        return 1
    fi

    echo "Downloading game: $game_name from ContentDB (author: $author)"
    
    if [ -d "$GAMES_DIR/$game_name" ]; then
        echo "  Game $game_name already exists, skipping..."
        return 0
    fi
    
    # Download from ContentDB
    local url="https://content.luanti.org/packages/${author}/${game_name}/download/"
    if [ -n "$release_id" ]; then
        url="https://content.luanti.org/packages/${author}/${game_name}/releases/${release_id}/download/"
    fi
    
    cd "$TEMP_DIR"
    wget -q "$url" -O "${game_name}.zip" || {
        echo "  Warning: Failed to download $game_name"
        return 1
    }
    
    # Extract and move to games directory
    unzip -q "${game_name}.zip" -d "${game_name}_extracted"
    
    # Find the game directory (it may be nested)
    local extracted_dir=$(find "${game_name}_extracted" -maxdepth 2 -type f -name "game.conf" | head -1)
    
    if [ -n "$extracted_dir" ]; then
        extracted_dir=$(dirname "$extracted_dir")
        mv "$extracted_dir" "$GAMES_DIR/$game_name"
        echo "  Successfully downloaded $game_name"
    else
        echo "  Warning: Could not find game files in archive"
        rm -rf "${game_name}_extracted" "${game_name}.zip"
        return 1
    fi
    
    rm -rf "${game_name}_extracted" "${game_name}.zip"
}

# Function to download a game from Git repository
download_git_game() {
    local game_name="$1"
    local repo_url="$2"
    local branch="${3:-master}"
    
    # Validate game_name contains only safe characters
    if ! [[ "$game_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "  Error: Invalid game name: $game_name"
        return 1
    fi
    
    echo "Downloading game: $game_name from $repo_url (branch: $branch)"
    
    if [ -d "$GAMES_DIR/$game_name" ]; then
        echo "  Game $game_name already exists, skipping..."
        return 0
    fi
    
    # Clone the repository
    git clone --depth 1 --branch "$branch" "$repo_url" "$TEMP_DIR/$game_name" || {
        echo "  Warning: Failed to download $game_name"
        return 1
    }
    
    # Move to games directory
    mv "$TEMP_DIR/$game_name" "$GAMES_DIR/$game_name"
    
    # Remove .git directory to save space
    rm -rf "$GAMES_DIR/$game_name/.git"
    
    echo "  Successfully downloaded $game_name"
}

# ========================================
# Game List
# Add games to download here
# ========================================

echo ""
echo "Starting game downloads..."
echo ""

# Download MineClone2 game from ContentDB release
# Note: Requires network access. If running in offline environment,
# place the game manually in $GAMES_DIR/mineclone2/
download_contentdb_game "mineclone2" "Wuzzy" "34113"

# Alternative: Download the latest ContentDB release without pinning
# download_contentdb_game "mineclone2" "Wuzzy"

echo ""
echo "=== Game download complete ==="
echo "Installed games in: $GAMES_DIR"
ls -1 "$GAMES_DIR" 2>/dev/null || echo "  (none)"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"
