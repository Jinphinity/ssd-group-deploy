#!/usr/bin/env bash
set -euo pipefail

GODOT_PATH="${GODOT_PATH:-/mnt/c/Tools/Godot/Godot_v4.4.1-stable_win64_console/Godot_v4.4.1-stable_win64_console.exe}"
PROJECT_PATH="${PROJECT_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../capstone" && pwd)}"
LOG_FILE="${LOG_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/logs/headless_run.log}"
EXTRA_ARGS=${EXTRA_ARGS:-"--headless --verbose --quit-on-finish"}
LOOP_UNTIL_SUCCESS=${LOOP_UNTIL_SUCCESS:-0}
MAX_ATTEMPTS=${MAX_ATTEMPTS:-3}
RESTART_DELAY=${RESTART_DELAY:-2}
NO_TAIL=${NO_TAIL:-0}

error_patterns=(
  "parse_error:Parse Error:"
  "load_fail:Failed to load script"
  "missing_file:File not found"
  "runtime_function:Invalid call"
  "runtime_assert:Condition \\"!"
)

declare -a timeline

launch_godot() {
  local attempt=$1
  rm -f "$LOG_FILE"

  echo "=== Headless Godot Attempt ${attempt} ==="
  local start_ts
  start_ts=$(date --iso-8601=seconds)
  timeline+=("[$start_ts] Started Godot attempt ${attempt}")

  set +e
  "${GODOT_PATH}" --path "${PROJECT_PATH}" ${EXTRA_ARGS} >"${LOG_FILE}" 2>&1 &
  local godot_pid=$!
  set -e

  local tail_pid=""
  if [[ "$NO_TAIL" != "1" ]]; then
    touch "$LOG_FILE"
    tail -n +1 -F "$LOG_FILE" |
    while IFS= read -r line; do
      printf '%s\n' "$line"
      for pattern in "${error_patterns[@]}"; do
        local type=${pattern%%:*}
        local regex=${pattern#*:}
        if [[ "$line" =~ $regex ]]; then
          printf 'AI_EVENT::error::%s::%s\n' "$type" "${line}"
          break
        fi
      done
    done &
    tail_pid=$!
  fi

  wait $godot_pid
  local exit_code=$?
  local end_ts
  end_ts=$(date --iso-8601=seconds)
  timeline+=("[$end_ts] Godot exited with code ${exit_code}")

  if [[ -n "$tail_pid" ]]; then
    kill "$tail_pid" >/dev/null 2>&1 || true
  fi

  printf '%s' "$exit_code"
}

collect_errors() {
  local -n _out=$1
  _out=()
  if [[ -f "$LOG_FILE" ]]; then
    while IFS= read -r line; do
      for pattern in "${error_patterns[@]}"; do
        local type=${pattern%%:*}
        local regex=${pattern#*:}
        if [[ "$line" =~ $regex ]]; then
          _out+=("${type}|${line}")
          break
        fi
      done
    done <"$LOG_FILE"
  fi
}

format_errors_json() {
  local -n _entries=$1
  if [[ ${#_entries[@]} -eq 0 ]]; then
    printf '[]'
    return
  fi

  printf '['
  local first=1
  for entry in "${_entries[@]}"; do
    local type=${entry%%|*}
    local message=${entry#*|}
    if [[ $first -eq 0 ]]; then
      printf ', '
    fi
    first=0
    printf '{"type": "%s", "message": "%s"}' "$type" "${message//"/\"}"
  done
  printf ']'
}

attempt=0
success=0
iteration_errors=()

while true; do
  attempt=$((attempt + 1))
  exit_code=$(launch_godot "$attempt")

  iteration_errors=()
  collect_errors iteration_errors

  if [[ "$exit_code" == "0" && ${#iteration_errors[@]} -eq 0 ]]; then
    success=1
    break
  fi

  if [[ "$LOOP_UNTIL_SUCCESS" != "1" || $attempt -ge $MAX_ATTEMPTS ]]; then
    break
  fi

  echo "Encountered errors. LoopUntilSuccess retry ${attempt}/${MAX_ATTEMPTS}."
  sleep "$RESTART_DELAY"
done

printf '=== Headless Run Summary ===\n'
printf '{\n'
printf '  "success": %s,\n' "$success"
printf '  "attempts": %s,\n' "$attempt"
printf '  "log_file": "%s",\n' "$LOG_FILE"
printf '  "timeline": ['
for i in "${!timeline[@]}"; do
  if [[ "$i" -gt 0 ]]; then
    printf ', '
  fi
  printf '"%s"' "${timeline[$i]}"

done
printf '],\n'
printf '  "errors": '
format_errors_json iteration_errors
printf '\n}\n'

if [[ $success -eq 1 ]]; then
  exit 0
fi

exit 1
