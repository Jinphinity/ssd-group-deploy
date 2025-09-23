#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/capstone}"
LOG_PATH="${LOG_PATH:-$ROOT_DIR/logs/godot_editor.log}"
GODOT_PATH="${GODOT_PATH:-/Applications/Godot.app/Contents/MacOS/Godot}"

if [[ ! -x "$GODOT_PATH" ]]; then
  if command -v godot4 >/dev/null 2>&1; then
    GODOT_PATH="$(command -v godot4)"
  elif command -v godot >/dev/null 2>&1; then
    GODOT_PATH="$(command -v godot)"
  else
    echo "Godot executable not found. Set GODOT_PATH env var when calling this script." >&2
    exit 1
  fi
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Project path '$PROJECT_PATH' does not exist." >&2
  exit 1
fi

mkdir -p "$(dirname "$LOG_PATH")"

echo "Starting Godot editor with log redirection"
echo "  Godot executable : $GODOT_PATH"
echo "  Project path     : $PROJECT_PATH"
echo "  Log file         : $LOG_PATH"

echo "Logs will be appended. Tail with: tail -f $LOG_PATH"

exec "$GODOT_PATH" -e --path "$PROJECT_PATH" --verbose >>"$LOG_PATH" 2>&1
