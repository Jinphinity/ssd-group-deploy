#!/bin/bash

# Quick transition test runner
# Automatically runs the game and triggers transitions to capture errors

echo "🚀 Starting automated transition testing..."

GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
PROJECT_DIR="/Users/vaisroi/Documents/Repositories/capstone/capstone"
LOG_FILE="/Users/vaisroi/Library/Application Support/Godot/app_userdata/Capstone/logs/godot.log"

cd "$PROJECT_DIR"

echo "🔧 Running transition test sequence..."

# Test 1: Start game and let it run for a few seconds to trigger natural transitions
echo "📋 Test 1: Natural gameplay transitions"
$GODOT --headless --quit-after 15 > /dev/null 2>&1

# Check for errors
echo "🔍 Checking for transition errors..."
if grep -E "(ERROR|Parameter.*null|data\.tree)" "$LOG_FILE" | tail -20; then
    echo "❌ Errors detected during transitions!"
    echo "🔧 Recent errors:"
    grep -E "(ERROR|Parameter.*null|data\.tree)" "$LOG_FILE" | tail -5
else
    echo "✅ No errors detected in transition test"
fi

echo "📊 Test completed. Check log for details."
echo "Log location: $LOG_FILE"