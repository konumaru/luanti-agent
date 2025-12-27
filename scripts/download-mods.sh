#!/bin/bash
set -euo pipefail

# MOD Download and Management Script
# This script downloads and configures mods for the Luanti AI agent experiments

MODS_DIR="${MODS_DIR:-/data/mods}"
TEMP_DIR="/tmp/luanti-mods"

echo "=== Luanti MOD Download Script ==="
echo "Mods directory: $MODS_DIR"

# Create mods directory if it doesn't exist
mkdir -p "$MODS_DIR"
mkdir -p "$TEMP_DIR"

# Function to download a mod from GitHub
download_github_mod() {
    local mod_name="$1"
    local repo_url="$2"
    local branch="${3:-master}"
    
    # Validate mod_name contains only safe characters
    if ! [[ "$mod_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "  Error: Invalid mod name: $mod_name"
        return 1
    fi
    
    echo "Downloading mod: $mod_name from $repo_url (branch: $branch)"
    
    if [ -d "$MODS_DIR/$mod_name" ]; then
        echo "  Mod $mod_name already exists, skipping..."
        return 0
    fi
    
    # Clone the repository
    git clone --depth 1 --branch "$branch" "$repo_url" "$TEMP_DIR/$mod_name" || {
        echo "  Warning: Failed to download $mod_name"
        return 1
    }
    
    # Move to mods directory
    mv "$TEMP_DIR/$mod_name" "$MODS_DIR/$mod_name"
    
    # Remove .git directory to save space
    rm -rf "$MODS_DIR/$mod_name/.git"
    
    echo "  Successfully downloaded $mod_name"
}

# Function to download a mod from ContentDB
download_contentdb_mod() {
    local mod_name="$1"
    local author="$2"
    
    # Validate parameters contain only safe characters
    if ! [[ "$mod_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "  Error: Invalid mod name: $mod_name"
        return 1
    fi
    if ! [[ "$author" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "  Error: Invalid author name: $author"
        return 1
    fi
    
    echo "Downloading mod: $mod_name from ContentDB (author: $author)"
    
    if [ -d "$MODS_DIR/$mod_name" ]; then
        echo "  Mod $mod_name already exists, skipping..."
        return 0
    fi
    
    # Download from ContentDB
    local url="https://content.minetest.net/packages/${author}/${mod_name}/download/"
    
    cd "$TEMP_DIR"
    wget -q "$url" -O "${mod_name}.zip" || {
        echo "  Warning: Failed to download $mod_name"
        return 1
    }
    
    # Extract and move to mods directory
    unzip -q "${mod_name}.zip" -d "${mod_name}_extracted"
    
    # Find the mod directory (it may be nested)
    local extracted_dir=$(find "${mod_name}_extracted" -maxdepth 2 -type f -name "mod.conf" -o -name "init.lua" | head -1 | xargs dirname)
    
    if [ -n "$extracted_dir" ] && [ -d "$extracted_dir" ]; then
        mv "$extracted_dir" "$MODS_DIR/$mod_name"
        echo "  Successfully downloaded $mod_name"
    else
        echo "  Warning: Could not find mod files in archive"
        rm -rf "${mod_name}_extracted" "${mod_name}.zip"
        return 1
    fi
    
    rm -rf "${mod_name}_extracted" "${mod_name}.zip"
}

# ========================================
# MOD List
# Add mods to download here
# ========================================

echo ""
echo "Starting mod downloads..."
echo ""

# Example: Mob mods for AI agent experiments
# Uncomment and modify as needed:

# download_contentdb_mod "mobs_redo" "TenPlus1"
# download_contentdb_mod "mobs_animal" "TenPlus1"
# download_contentdb_mod "mobs_monster" "TenPlus1"

# Example: Additional utility mods
# download_github_mod "worldedit" "https://github.com/Uberi/Minetest-WorldEdit.git" "master"

echo ""
echo "=== MOD download complete ==="
echo "Installed mods in: $MODS_DIR"
ls -1 "$MODS_DIR"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"
