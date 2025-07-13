#!/usr/bin/env bash
# sync-refreshed-profiles.sh - Sync refreshed profiles back to main directory

set -euo pipefail

MAIN_DIR="$HOME/.claude/cred_profiles"
REFRESHED_DIR="$HOME/.claude/cred_profiles_refreshed"
BACKUP_DIR="$HOME/.claude/cred_profiles_backup_$(date +%Y%m%d_%H%M%S)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Check if refreshed directory exists
if [ ! -d "$REFRESHED_DIR" ]; then
    echo -e "${RED}No refreshed profiles found at $REFRESHED_DIR${NC}"
    exit 1
fi

# Check if there are any refreshed files
if [ -z "$(ls -A "$REFRESHED_DIR" 2>/dev/null)" ]; then
    echo -e "${YELLOW}No refreshed profiles to sync${NC}"
    exit 0
fi

echo -e "${GREEN}Syncing refreshed OAuth tokens...${NC}"

# Create backup of current profiles
if [ -d "$MAIN_DIR" ]; then
    log "Backing up current profiles to $BACKUP_DIR"
    cp -r "$MAIN_DIR" "$BACKUP_DIR"
fi

# Sync refreshed profiles
for file in "$REFRESHED_DIR"/*.json; do
    [ -f "$file" ] || continue
    
    filename=$(basename "$file")
    profile="${filename%.json}"
    
    # Compare with existing
    if [ -f "$MAIN_DIR/$filename" ]; then
        if ! diff -q "$file" "$MAIN_DIR/$filename" >/dev/null; then
            log "Updating profile: $profile"
            cp "$file" "$MAIN_DIR/$filename"
        else
            log "Profile $profile unchanged"
        fi
    else
        log "Adding new profile: $profile"
        cp "$file" "$MAIN_DIR/$filename"
    fi
done

# Copy hidden files (like .current_profile)
for file in "$REFRESHED_DIR"/.*; do
    [ -f "$file" ] || continue
    filename=$(basename "$file")
    [ "$filename" = "." ] || [ "$filename" = ".." ] && continue
    
    cp "$file" "$MAIN_DIR/$filename"
done

# Clean up refreshed directory
log "Cleaning up refreshed directory"
rm -rf "$REFRESHED_DIR"/*

echo -e "${GREEN}✅ OAuth tokens synced successfully${NC}"
echo -e "Backup saved at: $BACKUP_DIR"