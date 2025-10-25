#!/bin/bash

# Watch for transition errors in real-time
# This script monitors the Godot log and automatically reports transition errors

echo "🔍 Starting transition error monitoring..."

GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
PROJECT_DIR="/Users/vaisroi/Documents/Repositories/capstone/capstone"
LOG_FILE="/Users/vaisroi/Library/Application Support/Godot/app_userdata/Capstone/logs/godot.log"

cd "$PROJECT_DIR"

# Clear previous log
> "$LOG_FILE"

echo "🎮 Starting game in background to trigger transitions..."

# Start Godot in background
$GODOT --headless --quit-after 20 > /dev/null 2>&1 &
GODOT_PID=$!

echo "📊 Process ID: $GODOT_PID"
echo "🔍 Monitoring log file: $LOG_FILE"
echo "⏰ Will run for 20 seconds..."

# Monitor log file for errors
timeout 25 tail -f "$LOG_FILE" | while read line; do
    if echo "$line" | grep -E "(ERROR|Parameter.*null|data\.tree|Invalid call)" > /dev/null; then
        echo "🚨 TRANSITION ERROR DETECTED:"
        echo "   $line"

        # Get some context around the error
        echo "📋 Context (last 5 lines):"
        tail -5 "$LOG_FILE" | sed 's/^/   /'
        echo ""
    fi

    # Also show transitions happening
    if echo "$line" | grep -E "(Transition|transition|🔄)" > /dev/null; then
        echo "🔄 TRANSITION: $line"
    fi
done

echo "✅ Monitoring completed"

# Check final results
echo "📊 Final error summary:"
grep -E "(ERROR|Parameter.*null|data\.tree|Invalid call)" "$LOG_FILE" | tail -10