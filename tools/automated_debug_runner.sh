#!/bin/bash

# Automated Game Debug Runner
# Iteratively runs the Godot game, captures runtime errors, and provides analysis
# Usage: ./automated_debug_runner.sh [options]

set -e

# Configuration
GODOT_EXECUTABLE="/Applications/Godot.app/Contents/MacOS/Godot"
PROJECT_PATH="/Users/vaisroi/Documents/Repositories/capstone/capstone"
LOG_DIR="${PROJECT_PATH}/logs"
GODOT_LOG_PATH="$HOME/Library/Application Support/Godot/app_userdata/Capstone/logs"
RUNTIME_DURATION=30  # seconds to run game per iteration
MAX_ITERATIONS=10
CURRENT_ITERATION=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌ $1${NC}"
}

# Function to check if Godot is available
check_godot() {
    if [ ! -f "$GODOT_EXECUTABLE" ]; then
        print_error "Godot not found at $GODOT_EXECUTABLE"
        print_status "Please install Godot or update the GODOT_EXECUTABLE path"
        exit 1
    fi
    print_success "Godot found at $GODOT_EXECUTABLE"
}

# Function to check project structure
check_project() {
    if [ ! -f "$PROJECT_PATH/project.godot" ]; then
        print_error "Godot project not found at $PROJECT_PATH"
        exit 1
    fi
    print_success "Project found at $PROJECT_PATH"
}

# Function to setup logging directories
setup_logging() {
    mkdir -p "$LOG_DIR"
    mkdir -p "$GODOT_LOG_PATH"

    # Clear previous runtime logs
    rm -f "${LOG_DIR}/runtime_debug_session_"*.log
    rm -f "${LOG_DIR}/error_analysis_"*.json

    print_success "Logging directories prepared"
}

# Function to get current log file sizes for monitoring
get_log_sizes() {
    GODOT_LOG_SIZE=0
    CUSTOM_LOG_SIZE=0

    if [ -f "${GODOT_LOG_PATH}/godot.log" ]; then
        GODOT_LOG_SIZE=$(stat -f%z "${GODOT_LOG_PATH}/godot.log" 2>/dev/null || echo 0)
    fi

    if [ -f "${PROJECT_PATH}/logs/capstone_runtime.log" ]; then
        CUSTOM_LOG_SIZE=$(stat -f%z "${PROJECT_PATH}/logs/capstone_runtime.log" 2>/dev/null || echo 0)
    fi
}

# Function to run game for specified duration
run_game_iteration() {
    local iteration=$1
    local session_log="${LOG_DIR}/runtime_debug_session_${iteration}.log"

    print_status "Starting game iteration $iteration/$MAX_ITERATIONS"

    # Get initial log sizes
    get_log_sizes
    local initial_godot_size=$GODOT_LOG_SIZE
    local initial_custom_size=$CUSTOM_LOG_SIZE

    # Start the game in background
    cd "$PROJECT_PATH"
    timeout $RUNTIME_DURATION "$GODOT_EXECUTABLE" --headless --debug > "$session_log" 2>&1 &
    local game_pid=$!

    print_status "Game running (PID: $game_pid) for ${RUNTIME_DURATION} seconds..."

    # Monitor for the specified duration
    local elapsed=0
    while [ $elapsed -lt $RUNTIME_DURATION ]; do
        sleep 1
        elapsed=$((elapsed + 1))

        # Check if game process is still running
        if ! kill -0 $game_pid 2>/dev/null; then
            print_warning "Game process terminated early after $elapsed seconds"
            break
        fi

        # Show progress every 5 seconds
        if [ $((elapsed % 5)) -eq 0 ]; then
            print_status "Game running... ${elapsed}/${RUNTIME_DURATION}s"
        fi
    done

    # Stop the game if still running
    if kill -0 $game_pid 2>/dev/null; then
        print_status "Stopping game process..."
        kill $game_pid 2>/dev/null || true
        sleep 2
        # Force kill if still running
        kill -9 $game_pid 2>/dev/null || true
    fi

    print_success "Game iteration $iteration completed"

    # Capture any new log content
    capture_new_logs $iteration $initial_godot_size $initial_custom_size
}

# Function to capture new log content since last check
capture_new_logs() {
    local iteration=$1
    local initial_godot_size=$2
    local initial_custom_size=$3

    local captured_log="${LOG_DIR}/captured_errors_${iteration}.log"
    > "$captured_log"  # Clear the file

    # Capture new Godot log content
    if [ -f "${GODOT_LOG_PATH}/godot.log" ]; then
        local current_godot_size=$(stat -f%z "${GODOT_LOG_PATH}/godot.log" 2>/dev/null || echo 0)
        if [ $current_godot_size -gt $initial_godot_size ]; then
            echo "=== NEW GODOT LOG CONTENT ===" >> "$captured_log"
            tail -c +$((initial_godot_size + 1)) "${GODOT_LOG_PATH}/godot.log" >> "$captured_log"
            echo "" >> "$captured_log"
        fi
    fi

    # Capture new custom log content
    if [ -f "${PROJECT_PATH}/logs/capstone_runtime.log" ]; then
        local current_custom_size=$(stat -f%z "${PROJECT_PATH}/logs/capstone_runtime.log" 2>/dev/null || echo 0)
        if [ $current_custom_size -gt $initial_custom_size ]; then
            echo "=== NEW CUSTOM LOG CONTENT ===" >> "$captured_log"
            tail -c +$((initial_custom_size + 1)) "${PROJECT_PATH}/logs/capstone_runtime.log" >> "$captured_log"
            echo "" >> "$captured_log"
        fi
    fi

    # Check if any errors were captured
    if [ -s "$captured_log" ]; then
        print_warning "New log content captured for iteration $iteration"
        analyze_captured_errors "$captured_log" $iteration
    else
        print_success "No new errors detected in iteration $iteration"
    fi
}

# Function to analyze captured errors
analyze_captured_errors() {
    local log_file=$1
    local iteration=$2

    print_status "Analyzing errors from iteration $iteration..."

    # Count different types of errors
    local error_count=$(grep -c "ERROR\|RUNTIME ERROR\|❌\|💥" "$log_file" 2>/dev/null || echo 0)
    local warning_count=$(grep -c "WARNING\|⚠️" "$log_file" 2>/dev/null || echo 0)
    local critical_count=$(grep -c "CRITICAL\|NULL_REFERENCE\|AUTOLOAD_FAILED" "$log_file" 2>/dev/null || echo 0)

    print_status "Error Analysis for Iteration $iteration:"
    echo "  - Errors: $error_count"
    echo "  - Warnings: $warning_count"
    echo "  - Critical: $critical_count"

    if [ $error_count -gt 0 ] || [ $critical_count -gt 0 ]; then
        print_error "Runtime errors detected! See $log_file for details"

        # Extract and categorize errors
        create_error_summary "$log_file" $iteration

        return 1  # Return error code to indicate issues found
    else
        print_success "No runtime errors in iteration $iteration"
        return 0
    fi
}

# Function to create error summary
create_error_summary() {
    local log_file=$1
    local iteration=$2
    local summary_file="${LOG_DIR}/error_summary_${iteration}.txt"

    echo "RUNTIME ERROR SUMMARY - Iteration $iteration" > "$summary_file"
    echo "Generated: $(date)" >> "$summary_file"
    echo "================================" >> "$summary_file"
    echo "" >> "$summary_file"

    # Extract different error types
    echo "CRITICAL ERRORS:" >> "$summary_file"
    grep -i "critical\|null_reference\|autoload_failed\|scene_instantiation_failed" "$log_file" >> "$summary_file" 2>/dev/null || echo "None found" >> "$summary_file"
    echo "" >> "$summary_file"

    echo "RUNTIME ERRORS:" >> "$summary_file"
    grep "💥 RUNTIME ERROR\|ERROR:" "$log_file" >> "$summary_file" 2>/dev/null || echo "None found" >> "$summary_file"
    echo "" >> "$summary_file"

    echo "FAILURES:" >> "$summary_file"
    grep "❌ FAILURE:" "$log_file" >> "$summary_file" 2>/dev/null || echo "None found" >> "$summary_file"
    echo "" >> "$summary_file"

    echo "WARNINGS:" >> "$summary_file"
    grep "WARNING\|⚠️" "$log_file" >> "$summary_file" 2>/dev/null || echo "None found" >> "$summary_file"

    print_status "Error summary created: $summary_file"
}

# Function to suggest fixes based on common error patterns
suggest_fixes() {
    local iteration=$1
    local log_file="${LOG_DIR}/captured_errors_${iteration}.log"

    if [ ! -f "$log_file" ]; then
        return
    fi

    print_status "Analyzing error patterns and suggesting fixes..."

    # Check for common error patterns
    if grep -q "Node not found\|get_node.*returns null" "$log_file"; then
        print_warning "DETECTED: Missing node references"
        echo "  💡 Suggestion: Check scene structure and node paths"
        echo "  💡 Verify all get_node() calls use correct paths"
    fi

    if grep -q "Invalid call\|method.*does not exist" "$log_file"; then
        print_warning "DETECTED: Invalid method calls"
        echo "  💡 Suggestion: Check method names and object types"
        echo "  💡 Verify objects are properly initialized before calling methods"
    fi

    if grep -q "Null Variant\|null object" "$log_file"; then
        print_warning "DETECTED: Null reference errors"
        echo "  💡 Suggestion: Add null checks before accessing objects"
        echo "  💡 Use assert_not_null() from FailureLogger for better debugging"
    fi

    if grep -q "Signal.*not connected\|connect.*failed" "$log_file"; then
        print_warning "DETECTED: Signal connection issues"
        echo "  💡 Suggestion: Check signal names and connection timing"
        echo "  💡 Ensure target objects exist before connecting signals"
    fi
}

# Function to run full debugging session
run_debug_session() {
    print_status "Starting automated debugging session"
    print_status "Max iterations: $MAX_ITERATIONS"
    print_status "Runtime per iteration: ${RUNTIME_DURATION}s"
    echo ""

    local total_errors=0
    local clean_iterations=0

    for i in $(seq 1 $MAX_ITERATIONS); do
        echo "════════════════════════════════════════"
        print_status "ITERATION $i/$MAX_ITERATIONS"
        echo "════════════════════════════════════════"

        run_game_iteration $i

        # Give a moment for logs to flush
        sleep 2

        # Analyze results
        if analyze_captured_errors "${LOG_DIR}/captured_errors_${i}.log" $i; then
            clean_iterations=$((clean_iterations + 1))
            print_success "Iteration $i completed without errors"
        else
            total_errors=$((total_errors + 1))
            suggest_fixes $i
        fi

        echo ""

        # Ask user if they want to continue (in interactive mode)
        if [ "$1" != "--auto" ]; then
            echo -n "Continue to next iteration? (y/n/auto): "
            read -r response
            case $response in
                n|N) break ;;
                auto|AUTO)
                    print_status "Switching to auto mode"
                    set -- "--auto"
                    ;;
            esac
        fi

        # Brief pause between iterations
        sleep 3
    done

    # Final summary
    echo ""
    echo "════════════════════════════════════════"
    print_status "DEBUGGING SESSION COMPLETE"
    echo "════════════════════════════════════════"
    print_status "Total iterations run: $CURRENT_ITERATION"
    print_status "Clean iterations: $clean_iterations"
    print_status "Iterations with errors: $total_errors"

    if [ $total_errors -eq 0 ]; then
        print_success "🎉 No runtime errors detected! Game appears stable."
    else
        print_warning "Runtime errors detected in $total_errors iterations"
        print_status "Check log files in $LOG_DIR for detailed analysis"
        print_status "Error summaries available for review and fixing"
    fi
}

# Function to show usage
show_usage() {
    echo "Automated Game Debug Runner"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --auto              Run all iterations automatically without prompts"
    echo "  --duration=N        Set runtime duration per iteration (default: 30s)"
    echo "  --iterations=N      Set maximum iterations (default: 10)"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                  Run interactively with default settings"
    echo "  $0 --auto           Run automatically for all iterations"
    echo "  $0 --duration=60    Run each iteration for 60 seconds"
    echo "  $0 --iterations=5   Limit to 5 iterations maximum"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto)
            AUTO_MODE=true
            shift
            ;;
        --duration=*)
            RUNTIME_DURATION="${1#*=}"
            shift
            ;;
        --iterations=*)
            MAX_ITERATIONS="${1#*=}"
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_status "Automated Game Debug Runner Starting..."

    # Pre-flight checks
    check_godot
    check_project
    setup_logging

    # Run the debugging session
    if [ "$AUTO_MODE" = true ]; then
        run_debug_session --auto
    else
        run_debug_session
    fi

    print_success "Debug session completed. Check $LOG_DIR for detailed logs."
}

# Execute main function
main "$@"