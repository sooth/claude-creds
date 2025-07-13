#!/bin/bash
# setup-auto-refresh.sh - Install automatic hourly token refresh

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLIST_FILE="$SCRIPT_DIR/com.claude.refresh.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Setting up automatic Claude token refresh...${NC}"

# Create LaunchAgents directory if it doesn't exist
mkdir -p "$LAUNCH_AGENTS_DIR"

# Check if already installed
if launchctl list | grep -q "com.claude.refresh"; then
    echo -e "${BLUE}Unloading existing service...${NC}"
    launchctl unload "$LAUNCH_AGENTS_DIR/com.claude.refresh.plist" 2>/dev/null || true
fi

# Copy plist file
echo -e "${BLUE}Installing launch agent...${NC}"
cp "$PLIST_FILE" "$LAUNCH_AGENTS_DIR/"

# Load the service
echo -e "${BLUE}Loading service...${NC}"
launchctl load "$LAUNCH_AGENTS_DIR/com.claude.refresh.plist"

# Verify it's loaded
if launchctl list | grep -q "com.claude.refresh"; then
    echo -e "${GREEN}✅ Auto-refresh service installed successfully!${NC}"
    echo ""
    echo "The service will:"
    echo "- Run every hour"
    echo "- Refresh OAuth tokens for all profiles"
    echo "- Log output to ~/.claude/sync_logs/"
    echo ""
    echo "To check status:"
    echo "  launchctl list | grep com.claude.refresh"
    echo ""
    echo "To uninstall:"
    echo "  launchctl unload ~/Library/LaunchAgents/com.claude.refresh.plist"
    echo "  rm ~/Library/LaunchAgents/com.claude.refresh.plist"
else
    echo -e "${RED}ERROR: Service failed to load${NC}"
    exit 1
fi