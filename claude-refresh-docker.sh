#!/usr/bin/env bash
# claude-refresh-docker.sh - Complete Docker-based token refresh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $0 [command]

Commands:
    prepare   Prepare Claude binary for Docker
    build     Build Docker image
    run       Run token refresh for all profiles
    clean     Clean up Docker resources

Example:
    $0 prepare  # First time setup
    $0 build    # Build image
    $0 run      # Refresh tokens
EOF
}

prepare_claude() {
    echo -e "${BLUE}Preparing Claude for Docker...${NC}"
    
    # Find Claude installation
    local claude_path=$(which claude)
    if [ -z "$claude_path" ]; then
        echo -e "${RED}ERROR: Claude not found in PATH${NC}"
        exit 1
    fi
    
    # Get the real path (resolve symlinks)
    local claude_real_path=$(readlink -f "$claude_path")
    local claude_dir=$(dirname "$claude_real_path")
    
    # Get Node.js version
    local node_version=$(node --version)
    echo "Found Node.js: $node_version"
    echo "Claude directory: $claude_dir"
    
    # Create directory structure
    mkdir -p "$SCRIPT_DIR/claude-docker/bin"
    
    # Copy Claude executable and dependencies
    echo "Copying Claude from: $claude_path"
    cp -f "$claude_path" "$SCRIPT_DIR/claude-docker/bin/claude"
    chmod +x "$SCRIPT_DIR/claude-docker/bin/claude"
    
    # Copy additional files that might be needed
    if [ -f "$claude_dir/yoga.wasm" ]; then
        echo "Copying yoga.wasm..."
        cp -f "$claude_dir/yoga.wasm" "$SCRIPT_DIR/claude-docker/bin/"
    fi
    
    # Copy any other .wasm or .node files
    for file in "$claude_dir"/*.{wasm,node}; do
        [ -f "$file" ] && cp -f "$file" "$SCRIPT_DIR/claude-docker/bin/"
    done
    
    echo -e "${GREEN}✅ Claude prepared for Docker${NC}"
}

build_image() {
    echo -e "${BLUE}Building Docker image...${NC}"
    
    docker build -t claude-refresh:latest .
    
    echo -e "${GREEN}✅ Docker image built${NC}"
}

run_refresh() {
    echo -e "${BLUE}Running token refresh...${NC}"
    
    # Create directories
    mkdir -p "$HOME/.claude/cred_profiles"
    mkdir -p "$HOME/.claude/cred_profiles_refreshed"
    mkdir -p "$HOME/.claude/sync_logs"
    
    # Get Node.js path from host
    local node_path=""
    if [ -d "$HOME/.nvm/versions/node" ]; then
        node_path=$(ls -d "$HOME/.nvm/versions/node"/v* | head -1)
    elif [ -d "/usr/local/lib/node_modules" ]; then
        node_path="/usr/local"
    fi
    
    if [ -z "$node_path" ]; then
        echo -e "${YELLOW}Warning: Could not find Node.js installation${NC}"
    fi
    
    # Run Docker container
    docker run --rm \
        -v "$HOME/.claude/cred_profiles:/creds:ro" \
        -v "$HOME/.claude/cred_profiles_refreshed:/output" \
        -v "$HOME/.claude/sync_logs:/logs" \
        -v "$SCRIPT_DIR/claude-docker:/opt/claude:ro" \
        ${node_path:+-v "$node_path:/opt/node:ro"} \
        ${node_path:+-e "NODE_PATH=/opt/node/lib/node_modules"} \
        ${node_path:+-e "PATH=/opt/claude/bin:/opt/node/bin:\$PATH"} \
        claude-refresh:latest
    
    # Check results
    echo -e "\n${GREEN}Checking results...${NC}"
    if [ -d "$HOME/.claude/cred_profiles_refreshed" ] && [ "$(ls -A "$HOME/.claude/cred_profiles_refreshed" 2>/dev/null)" ]; then
        echo -e "${GREEN}✅ Refreshed profiles found:${NC}"
        ls -la "$HOME/.claude/cred_profiles_refreshed"
        
        echo -e "\n${YELLOW}To sync refreshed tokens:${NC}"
        echo "  ./sync-refreshed-profiles.sh"
    else
        echo -e "${RED}No refreshed profiles found${NC}"
    fi
}

clean_docker() {
    echo -e "${YELLOW}Cleaning up Docker resources...${NC}"
    
    docker rmi claude-refresh:latest 2>/dev/null || true
    rm -rf "$SCRIPT_DIR/claude-docker"
    
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# Main
case "${1:-help}" in
    prepare)
        prepare_claude
        ;;
    build)
        build_image
        ;;
    run)
        if [ ! -f "$SCRIPT_DIR/claude-docker/bin/claude" ]; then
            echo -e "${YELLOW}Claude not prepared, running prepare first...${NC}"
            prepare_claude
        fi
        if ! docker image inspect claude-refresh:latest >/dev/null 2>&1; then
            echo -e "${YELLOW}Docker image not found, building...${NC}"
            build_image
        fi
        run_refresh
        ;;
    clean)
        clean_docker
        ;;
    help|--help|-h|*)
        usage
        ;;
esac