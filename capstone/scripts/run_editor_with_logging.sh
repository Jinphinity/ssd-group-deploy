#!/bin/bash

# Godot Editor with Logging - macOS/Linux
# Captures editor stdout/stderr to logs/godot_editor.log for CLI agent access

set -e

# Configuration
GODOT_PATH=${GODOT_PATH:-/Applications/Godot.app/Contents/MacOS/Godot}
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/godot_editor.log"
PROJECT_PATH=${PROJECT_PATH:-$(pwd)}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎮 Godot Editor with Logging${NC}"
echo -e "${BLUE}================================${NC}"

# Validate Godot installation
if [[ ! -f "$GODOT_PATH" ]]; then
    echo -e "${RED}❌ Godot not found at: $GODOT_PATH${NC}"
    echo -e "${YELLOW}💡 Set GODOT_PATH environment variable or install Godot at default location${NC}"
    echo -e "${YELLOW}   Example: export GODOT_PATH=/path/to/godot${NC}"
    exit 1
fi

# Create logs directory
mkdir -p "$LOG_DIR"

# Initialize log file with session header
echo "=================================================" >> "$LOG_FILE"
echo "Godot Editor Session Started: $(date)" >> "$LOG_FILE"
echo "Project Path: $PROJECT_PATH" >> "$LOG_FILE"
echo "Godot Path: $GODOT_PATH" >> "$LOG_FILE"
echo "=================================================" >> "$LOG_FILE"

echo -e "${GREEN}✅ Godot found: $GODOT_PATH${NC}"
echo -e "${GREEN}✅ Logging to: $LOG_FILE${NC}"
echo -e "${YELLOW}📝 Monitor logs in another terminal:${NC}"
echo -e "${BLUE}   tail -f $LOG_FILE${NC}"
echo ""
echo -e "${YELLOW}🚀 Starting Godot Editor...${NC}"

# Function to handle cleanup on script exit
cleanup() {
    echo "=================================================" >> "$LOG_FILE"
    echo "Godot Editor Session Ended: $(date)" >> "$LOG_FILE"
    echo "=================================================" >> "$LOG_FILE"
    echo ""
    echo -e "${YELLOW}📝 Editor session logged to: $LOG_FILE${NC}"
}

# Set up cleanup trap
trap cleanup EXIT

# Launch Godot editor with logging
# 2>&1 captures both stdout and stderr
# tee -a appends to log file while showing output
cd "$PROJECT_PATH"
"$GODOT_PATH" --editor --path "$PROJECT_PATH" 2>&1 | tee -a "$LOG_FILE"