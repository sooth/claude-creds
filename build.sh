#!/bin/bash
# build.sh - Build the Claude refresh Docker image

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Building Claude refresh Docker image...${NC}"

# Build the Docker image
if docker build -t claude-refresh:latest .; then
    echo -e "${GREEN}✅ Docker image built successfully${NC}"
    echo ""
    echo "Image details:"
    docker images claude-refresh:latest
    echo ""
    echo "To run the refresh:"
    echo "  ./claude-refresh-docker.sh run"
else
    echo -e "${RED}❌ Docker build failed${NC}"
    exit 1
fi