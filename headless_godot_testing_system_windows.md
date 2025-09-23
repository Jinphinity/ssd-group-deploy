# Headless Godot Testing System for Windows

**Platform**: Windows 10/11  
**Engine**: Godot 4.4.1 (Win64 Console build)  
**Integration Target**: CLI-first AI agents (Claude Code, Open Interpreter, Codex CLI)  
**Status**: Draft Implementation Guide

---
## Implementation Status (2025-09-22)

- [x] `scripts/run_godot_headless.ps1` - automated launch/tail/error classification with optional restart loop
- [x] `scripts/run_godot_headless.sh` - WSL/Git Bash parity runner
- [x] `scripts/watch_godot_log.py` - standalone log follower emitting `AI_EVENT` markers
- [ ] Expand Windows-specific auto-fix recipes (next iteration)


## 1. Executive Summary

This guide adapts the macOS headless automation pipeline to Windows. It shows how to launch Godot headlessly from the console, capture its stdout/stderr for AI parsing, and orchestrate iterative build/test/debug cycles entirely through automation. The design assumes:

- The Godot **console** executable is available (e.g. `Godot_v4.4.1-stable_win64_console.exe`).
- AI agents can execute PowerShell/Bash commands in the project directory.
- Logs must land in predictable files so the agent can tail them and respond to failures.

---

## 2. Component Overview

| Component | Windows Equivalent | Notes |
|-----------|-------------------|-------|
| Direct executable access | Full path to `Godot_v4.4.1-stable_win64_console.exe` | No PATH edits required. |
| Background process manager | PowerShell `Start-Process` with `-PassThru` | Supports non-blocking runs and termination. |
| Console monitor | `Get-Content -Wait` or `Get-CimInstance Win32_Process` | Streams logs to agent for parsing. |
| Error detection engine | Regex filters (PowerShell / Python) | Look for `ERROR:` / `Parse Error:` patterns. |
| Test harness | `--headless`, `--run`, `--quit`, `--path` | Works for unit tests, scenes, or scripts. |
| Screenshot capture (optional) | `--headless --export-pack` or `--capture` (export template) | Requires GPUless run-skip if not needed. |

---

## 3. Direct Executable Access Layer

### 3.1 Locate Console Build

Recommended install location:

```
C:\Tools\Godot\Godot_v4.4.1-stable_win64_console\Godot_v4.4.1-stable_win64_console.exe
```

Alternative locations:

- `%ProgramFiles%\Godot\Godot_v4.4.1\Godot_v4.4.1-stable_win64_console.exe`
- Repository-local copy in `tools/`

> **Why console build?** Standard GUI builds suppress stdout until exit. The console build streams logs live, which is mandatory for automated parsing.

### 3.2 Launch Parameters

```
& $GODOT_EXE --headless --path C:\repo\capstone\capstone --verbose --quit-on-finish --script res://scripts/HeadlessTestRunner.gd
```

Key flags:

- `--headless` - disables window creation (CI-friendly).
- `--path <project>` - points to folder with `project.godot`.
- `--verbose` - emits detailed log lines (parser-friendly).
- `--quit-on-finish` - exits automatically after script/test run.
- `--script` or `--run <scene>` - entry point for tests/integration flows.

---

## 4. Background Process Management

### 4.1 Automated Runner Script

`scripts/run_godot_headless.ps1` wraps the Windows console build and now handles logging, live tailing, error classification, and optional retry loops.

```powershell
# one-shot launch with defaults
powershell.exe -NoProfile -File .\scripts\run_godot_headless.ps1 `
  -GodotPath "C:\\Tools\\Godot\\Godot_v4.4.1-stable_win64_console\\Godot_v4.4.1-stable_win64_console.exe"

# restart automatically until success (max 5 attempts)
powershell.exe -NoProfile -File .\scripts\run_godot_headless.ps1 `
  -LoopUntilSuccess -MaxAttempts 5 `
  -ExtraArgs @('--headless','--verbose','--quit-on-finish','--run-tests')
```

**Default behavior:**
- Launches with `--path <project>` plus entries from `-ExtraArgs`
- Streams `./logs/headless_run.log` to stdout (disable with `-NoTail`)
- Emits `AI_EVENT::error::<type>::...` for critical patterns (Parse Error, Failed to load script, File not found, Invalid call, Condition "...")
- Parses the log on exit and prints a JSON summary (suppress with `-SilentSummary`)
- Records a simple timeline for downstream tooling

**Example summary output:**

```json
{
  "success": false,
  "attempts": 1,
  "log_file": "C:\\Users\\jinph\\Documents\\00_Repositories\\capstone\\logs\\headless_run.log",
  "errors": [
    {
      "type": "missing_file",
      "message": "ERROR: Failed loading resource: res://utilities/sprite_manager.gd"
    }
  ],
  "timeline": [
    "[2025-09-22T05:14:02.6180000] Started Godot (PID 12345)",
    "[2025-09-22T05:14:03.1100000] Godot exited with code 1"
  ]
}
```

### 4.2 WSL/Git Bash Runner

`./scripts/run_godot_headless.sh` mirrors the PowerShell runner for WSL or Git Bash environments. It tails the same log, emits `AI_EVENT` markers, and returns a JSON summary.

```bash
GODOT_PATH="/mnt/c/Tools/Godot/.../Godot_v4.4.1-stable_win64_console.exe" \
PROJECT_PATH="$(wslpath 'C:\\Users\\jinph\\Documents\\00_Repositories\\capstone\\capstone')" \
LOOP_UNTIL_SUCCESS=1 MAX_ATTEMPTS=5 \
bash ./scripts/run_godot_headless.sh
```

Set `NO_TAIL=1` to suppress live output or override `LOG_FILE` for alternate runs.

### 4.3 Termination

```
Stop-Process -Id $pid -Force
```

Use this when you need to abort a hung process manually; the runner scripts automatically clean up their own tails.

---

## 5. Live Console Monitoring

### 5.1 Built-in Tail

Both `run_godot_headless.ps1` and `run_godot_headless.sh` stream `./logs/headless_run.log` and emit `AI_EVENT::error::<type>::...` as soon as a known pattern matches. Disable the tail with `-NoTail` or `NO_TAIL=1` when you only need the JSON summary.

### 5.2 Dedicated Watcher Utility

`scripts/watch_godot_log.py` provides cross-platform log monitoring.

```powershell
python .\scripts\watch_godot_log.py .\logs\headless_run.log --follow
```

Use `--once` to process a finished run, and append `--json` to emit a machine-readable summary for downstream tools.

### 5.3 PowerShell One-Liner

For ad-hoc investigations, a minimal tail keeps errors visible without the helper scripts:

```powershell
Get-Content -Path .\logs\headless_run.log -Wait | ForEach-Object {
    $_
    if ($_ -match 'ERROR:' -or $_ -match 'Parse Error:') {
        "AI_EVENT::error::raw::$_"
    }
}
```

---## 6. Automated Test Configuration

### 6.1 Built-In Godot Test Runner

```
& $GODOT_EXE --headless --path .\capstone --run-tests --test TAP res://tests > logs\tests.tap 2>&1
```

- `--run-tests` executes Godot's native unit tests (if present).  
- `--test TAP` outputs TAP format (easy to parse).  
- AI tailer parses `logs\tests.tap` for failures.

### 6.2 Custom Integration Scripts

Create `res://scripts/HeadlessTestRunner.gd` to orchestrate gameplay scenarios. Example snippet:

```gdscript
extends SceneTree

func _init():
    var errors = []
    # Load main scene, simulate actions, gather metrics
    # ...
    if errors.is_empty():
        print("HEADLESS_PASS")
    else:
        for err in errors:
            push_error(err)
    quit()
```

Launch with `--script res://scripts/HeadlessTestRunner.gd`.

---

## 7. Error Detection & Auto-Remediation Workflow

### 7.1 Recommended Regex Patterns

| Pattern | Meaning | Action |
|------|---------|-----|
| `Parse Error:` | Compilation failure | Open offending file, correct syntax. |
| `Failed to load script` | Missing dependency or syntax error | Validate import paths or re-run parser. |
| `ERROR: In GVFS` | Missing resources | Ensure `.import` files or assets exist. |
| `Condition "!is_inside_tree" is true.` | Node lifecycle bug | Add guards before use. |

Implementation: AI tail process tags lines and selects remediation recipes (edit file, re-run command, etc.).

### 7.2 Restart Strategy

- Manual loop: `Stop-Process -Id <pid>` to halt the current run, apply fixes, and relaunch with updated arguments.
- Automated loop: `powershell.exe -NoProfile -File .\scripts\run_godot_headless.ps1 -LoopUntilSuccess -MaxAttempts 5 -RestartDelaySeconds 3` reruns until the exit code is 0 and no critical errors are detected.
- WSL/Git Bash loop: `LOOP_UNTIL_SUCCESS=1 MAX_ATTEMPTS=5 bash ./scripts/run_godot_headless.sh` offers the same behavior.

### 7.3 Error Summary Hooks

- Snapshot the latest run with `python .\scripts\watch_godot_log.py .\logs\headless_run.log --once --json`.
- Feed the JSON summary back into your agent to select remediation recipes per error `type`.
- Persist log artifacts (e.g., `logs/headless_run.log`) when handing context to another AI or a human developer.

---

## 8. Game State & Visual Testing (Optional)

Windows lacks a built-in screenshot flag for headless runs, but you can:

- Launch with `--headless --rendering-driver opengl3` and a custom script to capture viewport textures to PNG.
- Invoke `ViewportTexture.get_data().save_png("user://captures/frame.png")` within the test script.

AI agents retrieve images from `%APPDATA%\Godot\app_userdata\Capstone\captures`.

---

## 9. Integration with AI Development Environments

### 9.1 Claude Code / Open Interpreter

- Grant shell access.
- Configure reusable commands (e.g., `/godot headless`, `/godot tail`).
- Persist `$env:GODOT_EXE` in session for reuse.

### 9.2 Codex CLI (current environment)

- Use `powershell.exe -NoProfile -Command` invocations.
- Ensure the console executable lives within accessible directories (repo, tools folder, or absolute path).
- Define helper scripts in `scripts/` (already partially present) so the AI can call them by filename.

### 9.3 CI/CD (GitHub Actions, etc.)

- Add a Windows runner job with the console build cached.
- Use `actions/cache` to store the `Godot_v4.4.1-stable_win64_console.exe` binary.
- Run integration tests via PowerShell steps and upload logs/artifacts on failure.

---

## 10. Troubleshooting Quick Reference

| Symptom | Fix |
|---------|-----|
| **Console output empty** | Use console build, verify redirection (`*>` vs `*>>`). |
| **Editor opens GUI** | Missing `--headless` or wrong executable. |
| **Parse errors** | Tail log, apply fixes, re-run. Ensure scripts use Godot syntax (`? :`). |
| **Process hangs** | Confirm `--quit-on-finish` or send `Stop-Process`. |
| **File path issues** | Use absolute Windows paths, wrap in quotes. |

---

## 11. Suggested Next Steps

- [ ] Place the console executable under `tools/` or document its system path for the automation scripts.
- [x] Add `scripts/run_godot_headless.ps1` and `scripts/run_godot_headless.sh` for Windows and WSL runners.
- [x] Teach AI agents to launch and monitor via the new scripts (see Section 12 for loop pseudo-code).
- [ ] Extend `capstone/docs/Logging.md` with a Windows headless section referencing this guide.
- [ ] Port the macOS visual testing harness by scripting PNG captures in Godot.

---

**Document Version:** 0.9  
**Last Updated:** September 22, 2025  
**Author:** Auto-generated by Codex CLI  
**Scope:** Windows adaptation of macOS headless automation blueprint






    if (# Headless Godot Testing System for Windows

**Platform**: Windows 10/11  
**Engine**: Godot 4.4.1 (Win64 Console build)  
**Integration Target**: CLI-first AI agents (Claude Code, Open Interpreter, Codex CLI)  
**Status**: Draft Implementation Guide

---
## Implementation Status (2025-09-22)

- [x] `scripts/run_godot_headless.ps1` - automated launch/tail/error classification with optional restart loop
- [x] `scripts/run_godot_headless.sh` - WSL/Git Bash parity runner
- [x] `scripts/watch_godot_log.py` - standalone log follower emitting `AI_EVENT` markers
- [ ] Expand Windows-specific auto-fix recipes (next iteration)


## 1. Executive Summary

This guide adapts the macOS headless automation pipeline to Windows. It shows how to launch Godot headlessly from the console, capture its stdout/stderr for AI parsing, and orchestrate iterative build/test/debug cycles entirely through automation. The design assumes:

- The Godot **console** executable is available (e.g. `Godot_v4.4.1-stable_win64_console.exe`).
- AI agents can execute PowerShell/Bash commands in the project directory.
- Logs must land in predictable files so the agent can tail them and respond to failures.

---

## 2. Component Overview

| Component | Windows Equivalent | Notes |
|-----------|-------------------|-------|
| Direct executable access | Full path to `Godot_v4.4.1-stable_win64_console.exe` | No PATH edits required. |
| Background process manager | PowerShell `Start-Process` with `-PassThru` | Supports non-blocking runs and termination. |
| Console monitor | `Get-Content -Wait` or `Get-CimInstance Win32_Process` | Streams logs to agent for parsing. |
| Error detection engine | Regex filters (PowerShell / Python) | Look for `ERROR:` / `Parse Error:` patterns. |
| Test harness | `--headless`, `--run`, `--quit`, `--path` | Works for unit tests, scenes, or scripts. |
| Screenshot capture (optional) | `--headless --export-pack` or `--capture` (export template) | Requires GPUless run-skip if not needed. |

---

## 3. Direct Executable Access Layer

### 3.1 Locate Console Build

Recommended install location:

```
C:\Tools\Godot\Godot_v4.4.1-stable_win64_console\Godot_v4.4.1-stable_win64_console.exe
```

Alternative locations:

- `%ProgramFiles%\Godot\Godot_v4.4.1\Godot_v4.4.1-stable_win64_console.exe`
- Repository-local copy in `tools/`

> **Why console build?** Standard GUI builds suppress stdout until exit. The console build streams logs live, which is mandatory for automated parsing.

### 3.2 Launch Parameters

```
& $GODOT_EXE --headless --path C:\repo\capstone\capstone --verbose --quit-on-finish --script res://scripts/HeadlessTestRunner.gd
```

Key flags:

- `--headless` - disables window creation (CI-friendly).
- `--path <project>` - points to folder with `project.godot`.
- `--verbose` - emits detailed log lines (parser-friendly).
- `--quit-on-finish` - exits automatically after script/test run.
- `--script` or `--run <scene>` - entry point for tests/integration flows.

---

## 4. Background Process Management

### 4.1 Automated Runner Script

`scripts/run_godot_headless.ps1` wraps the Windows console build and now handles logging, live tailing, error classification, and optional retry loops.

```powershell
# one-shot launch with defaults
powershell.exe -NoProfile -File .\scripts\run_godot_headless.ps1 `
  -GodotPath "C:\\Tools\\Godot\\Godot_v4.4.1-stable_win64_console\\Godot_v4.4.1-stable_win64_console.exe"

# restart automatically until success (max 5 attempts)
powershell.exe -NoProfile -File .\scripts\run_godot_headless.ps1 `
  -LoopUntilSuccess -MaxAttempts 5 `
  -ExtraArgs @('--headless','--verbose','--quit-on-finish','--run-tests')
```

**Default behavior:**
- Launches with `--path <project>` plus entries from `-ExtraArgs`
- Streams `./logs/headless_run.log` to stdout (disable with `-NoTail`)
- Emits `AI_EVENT::error::<type>::...` for critical patterns (Parse Error, Failed to load script, File not found, Invalid call, Condition "...")
- Parses the log on exit and prints a JSON summary (suppress with `-SilentSummary`)
- Records a simple timeline for downstream tooling

**Example summary output:**

```json
{
  "success": false,
  "attempts": 1,
  "log_file": "C:\\Users\\jinph\\Documents\\00_Repositories\\capstone\\logs\\headless_run.log",
  "errors": [
    {
      "type": "missing_file",
      "message": "ERROR: Failed loading resource: res://utilities/sprite_manager.gd"
    }
  ],
  "timeline": [
    "[2025-09-22T05:14:02.6180000] Started Godot (PID 12345)",
    "[2025-09-22T05:14:03.1100000] Godot exited with code 1"
  ]
}
```

### 4.2 WSL/Git Bash Runner

`./scripts/run_godot_headless.sh` mirrors the PowerShell runner for WSL or Git Bash environments. It tails the same log, emits `AI_EVENT` markers, and returns a JSON summary.

```bash
GODOT_PATH="/mnt/c/Tools/Godot/.../Godot_v4.4.1-stable_win64_console.exe" \
PROJECT_PATH="$(wslpath 'C:\\Users\\jinph\\Documents\\00_Repositories\\capstone\\capstone')" \
LOOP_UNTIL_SUCCESS=1 MAX_ATTEMPTS=5 \
bash ./scripts/run_godot_headless.sh
```

Set `NO_TAIL=1` to suppress live output or override `LOG_FILE` for alternate runs.

### 4.3 Termination

```
Stop-Process -Id $pid -Force
```

Use this when you need to abort a hung process manually; the runner scripts automatically clean up their own tails.

---

## 5. Live Console Monitoring

### 5.1 Tail Utility

Use a second PowerShell process (or AI shell session):

```powershell
Get-Content -Path .\logs\headless_run.log -Wait | ForEach-Object {
    $_
    if ($_ -match 'ERROR:') {
        # Emit structured JSON for AI agent
        "AI_EVENT::error::$_"
    }
}
```

AI agents watch for `AI_EVENT::error` to trigger remediation steps.

### 5.2 Structured Parser (optional)

A lightweight Python watcher (invoked by AI) can categorize errors:

```python
import re, sys
ERROR_PATTERNS = {
    'parse_error': re.compile(r'Parse Error:'),
    'load_fail': re.compile(r'Failed to load script')
}
for line in sys.stdin:
    print(line, end='')
    for key, pat in ERROR_PATTERNS.items():
        if pat.search(line):
            print(f"AI_EVENT::error::{key}::{line.strip()}")
            sys.stdout.flush()
```

Run via `python watch_godot_log.py < logs\headless_run.log`.

---

## 6. Automated Test Configuration

### 6.1 Built-In Godot Test Runner

```
& $GODOT_EXE --headless --path .\capstone --run-tests --test TAP res://tests > logs\tests.tap 2>&1
```

- `--run-tests` executes Godot's native unit tests (if present).  
- `--test TAP` outputs TAP format (easy to parse).  
- AI tailer parses `logs\tests.tap` for failures.

### 6.2 Custom Integration Scripts

Create `res://scripts/HeadlessTestRunner.gd` to orchestrate gameplay scenarios. Example snippet:

```gdscript
extends SceneTree

func _init():
    var errors = []
    # Load main scene, simulate actions, gather metrics
    # ...
    if errors.is_empty():
        print("HEADLESS_PASS")
    else:
        for err in errors:
            push_error(err)
    quit()
```

Launch with `--script res://scripts/HeadlessTestRunner.gd`.

---

## 7. Error Detection & Auto-Remediation Workflow

### 7.1 Recommended Regex Patterns

| Pattern | Meaning | Action |
|------|---------|-----|
| `Parse Error:` | Compilation failure | Open offending file, correct syntax. |
| `Failed to load script` | Missing dependency or syntax error | Validate import paths or re-run parser. |
| `ERROR: In GVFS` | Missing resources | Ensure `.import` files or assets exist. |
| `Condition "!is_inside_tree" is true.` | Node lifecycle bug | Add guards before use. |

Implementation: AI tail process tags lines and selects remediation recipes (edit file, re-run command, etc.).

### 7.2 Restart Strategy

- Manual loop: `Stop-Process -Id <pid>` to halt the current run, apply fixes, and relaunch with updated arguments.
- Automated loop: `powershell.exe -NoProfile -File .\scripts\run_godot_headless.ps1 -LoopUntilSuccess -MaxAttempts 5 -RestartDelaySeconds 3` reruns until the exit code is 0 and no critical errors are detected.
- WSL/Git Bash loop: `LOOP_UNTIL_SUCCESS=1 MAX_ATTEMPTS=5 bash ./scripts/run_godot_headless.sh` offers the same behavior.

### 7.3 Error Summary Hooks

- Snapshot the latest run with `python .\scripts\watch_godot_log.py .\logs\headless_run.log --once --json`.
- Feed the JSON summary back into your agent to select remediation recipes per error `type`.
- Persist log artifacts (e.g., `logs/headless_run.log`) when handing context to another AI or a human developer.

---

## 8. Game State & Visual Testing (Optional)

Windows lacks a built-in screenshot flag for headless runs, but you can:

- Launch with `--headless --rendering-driver opengl3` and a custom script to capture viewport textures to PNG.
- Invoke `ViewportTexture.get_data().save_png("user://captures/frame.png")` within the test script.

AI agents retrieve images from `%APPDATA%\Godot\app_userdata\Capstone\captures`.

---

## 9. Integration with AI Development Environments

### 9.1 Claude Code / Open Interpreter

- Grant shell access.
- Configure reusable commands (e.g., `/godot headless`, `/godot tail`).
- Persist `$env:GODOT_EXE` in session for reuse.

### 9.2 Codex CLI (current environment)

- Use `powershell.exe -NoProfile -Command` invocations.
- Ensure the console executable lives within accessible directories (repo, tools folder, or absolute path).
- Define helper scripts in `scripts/` (already partially present) so the AI can call them by filename.

### 9.3 CI/CD (GitHub Actions, etc.)

- Add a Windows runner job with the console build cached.
- Use `actions/cache` to store the `Godot_v4.4.1-stable_win64_console.exe` binary.
- Run integration tests via PowerShell steps and upload logs/artifacts on failure.

---

## 10. Troubleshooting Quick Reference

| Symptom | Fix |
|---------|-----|
| **Console output empty** | Use console build, verify redirection (`*>` vs `*>>`). |
| **Editor opens GUI** | Missing `--headless` or wrong executable. |
| **Parse errors** | Tail log, apply fixes, re-run. Ensure scripts use Godot syntax (`? :`). |
| **Process hangs** | Confirm `--quit-on-finish` or send `Stop-Process`. |
| **File path issues** | Use absolute Windows paths, wrap in quotes. |

---

## 11. Suggested Next Steps

- [ ] Place the console executable under `tools/` or document its system path for the automation scripts.
- [x] Add `scripts/run_godot_headless.ps1` and `scripts/run_godot_headless.sh` for Windows and WSL runners.
- [x] Teach AI agents to launch and monitor via the new scripts (see Section 12 for loop pseudo-code).
- [ ] Extend `capstone/docs/Logging.md` with a Windows headless section referencing this guide.
- [ ] Port the macOS visual testing harness by scripting PNG captures in Godot.

---

**Document Version:** 0.9  
**Last Updated:** September 22, 2025  
**Author:** Auto-generated by Codex CLI  
**Scope:** Windows adaptation of macOS headless automation blueprint





 -match 'ERROR:' -or # Headless Godot Testing System for Windows

**Platform**: Windows 10/11  
**Engine**: Godot 4.4.1 (Win64 Console build)  
**Integration Target**: CLI-first AI agents (Claude Code, Open Interpreter, Codex CLI)  
**Status**: Draft Implementation Guide

---
## Implementation Status (2025-09-22)

- [x] `scripts/run_godot_headless.ps1` - automated launch/tail/error classification with optional restart loop
- [x] `scripts/run_godot_headless.sh` - WSL/Git Bash parity runner
- [x] `scripts/watch_godot_log.py` - standalone log follower emitting `AI_EVENT` markers
- [ ] Expand Windows-specific auto-fix recipes (next iteration)


## 1. Executive Summary

This guide adapts the macOS headless automation pipeline to Windows. It shows how to launch Godot headlessly from the console, capture its stdout/stderr for AI parsing, and orchestrate iterative build/test/debug cycles entirely through automation. The design assumes:

- The Godot **console** executable is available (e.g. `Godot_v4.4.1-stable_win64_console.exe`).
- AI agents can execute PowerShell/Bash commands in the project directory.
- Logs must land in predictable files so the agent can tail them and respond to failures.

---

## 2. Component Overview

| Component | Windows Equivalent | Notes |
|-----------|-------------------|-------|
| Direct executable access | Full path to `Godot_v4.4.1-stable_win64_console.exe` | No PATH edits required. |
| Background process manager | PowerShell `Start-Process` with `-PassThru` | Supports non-blocking runs and termination. |
| Console monitor | `Get-Content -Wait` or `Get-CimInstance Win32_Process` | Streams logs to agent for parsing. |
| Error detection engine | Regex filters (PowerShell / Python) | Look for `ERROR:` / `Parse Error:` patterns. |
| Test harness | `--headless`, `--run`, `--quit`, `--path` | Works for unit tests, scenes, or scripts. |
| Screenshot capture (optional) | `--headless --export-pack` or `--capture` (export template) | Requires GPUless run-skip if not needed. |

---

## 3. Direct Executable Access Layer

### 3.1 Locate Console Build

Recommended install location:

```
C:\Tools\Godot\Godot_v4.4.1-stable_win64_console\Godot_v4.4.1-stable_win64_console.exe
```

Alternative locations:

- `%ProgramFiles%\Godot\Godot_v4.4.1\Godot_v4.4.1-stable_win64_console.exe`
- Repository-local copy in `tools/`

> **Why console build?** Standard GUI builds suppress stdout until exit. The console build streams logs live, which is mandatory for automated parsing.

### 3.2 Launch Parameters

```
& $GODOT_EXE --headless --path C:\repo\capstone\capstone --verbose --quit-on-finish --script res://scripts/HeadlessTestRunner.gd
```

Key flags:

- `--headless` - disables window creation (CI-friendly).
- `--path <project>` - points to folder with `project.godot`.
- `--verbose` - emits detailed log lines (parser-friendly).
- `--quit-on-finish` - exits automatically after script/test run.
- `--script` or `--run <scene>` - entry point for tests/integration flows.

---

## 4. Background Process Management

### 4.1 Automated Runner Script

`scripts/run_godot_headless.ps1` wraps the Windows console build and now handles logging, live tailing, error classification, and optional retry loops.

```powershell
# one-shot launch with defaults
powershell.exe -NoProfile -File .\scripts\run_godot_headless.ps1 `
  -GodotPath "C:\\Tools\\Godot\\Godot_v4.4.1-stable_win64_console\\Godot_v4.4.1-stable_win64_console.exe"

# restart automatically until success (max 5 attempts)
powershell.exe -NoProfile -File .\scripts\run_godot_headless.ps1 `
  -LoopUntilSuccess -MaxAttempts 5 `
  -ExtraArgs @('--headless','--verbose','--quit-on-finish','--run-tests')
```

**Default behavior:**
- Launches with `--path <project>` plus entries from `-ExtraArgs`
- Streams `./logs/headless_run.log` to stdout (disable with `-NoTail`)
- Emits `AI_EVENT::error::<type>::...` for critical patterns (Parse Error, Failed to load script, File not found, Invalid call, Condition "...")
- Parses the log on exit and prints a JSON summary (suppress with `-SilentSummary`)
- Records a simple timeline for downstream tooling

**Example summary output:**

```json
{
  "success": false,
  "attempts": 1,
  "log_file": "C:\\Users\\jinph\\Documents\\00_Repositories\\capstone\\logs\\headless_run.log",
  "errors": [
    {
      "type": "missing_file",
      "message": "ERROR: Failed loading resource: res://utilities/sprite_manager.gd"
    }
  ],
  "timeline": [
    "[2025-09-22T05:14:02.6180000] Started Godot (PID 12345)",
    "[2025-09-22T05:14:03.1100000] Godot exited with code 1"
  ]
}
```

### 4.2 WSL/Git Bash Runner

`./scripts/run_godot_headless.sh` mirrors the PowerShell runner for WSL or Git Bash environments. It tails the same log, emits `AI_EVENT` markers, and returns a JSON summary.

```bash
GODOT_PATH="/mnt/c/Tools/Godot/.../Godot_v4.4.1-stable_win64_console.exe" \
PROJECT_PATH="$(wslpath 'C:\\Users\\jinph\\Documents\\00_Repositories\\capstone\\capstone')" \
LOOP_UNTIL_SUCCESS=1 MAX_ATTEMPTS=5 \
bash ./scripts/run_godot_headless.sh
```

Set `NO_TAIL=1` to suppress live output or override `LOG_FILE` for alternate runs.

### 4.3 Termination

```
Stop-Process -Id $pid -Force
```

Use this when you need to abort a hung process manually; the runner scripts automatically clean up their own tails.

---

## 5. Live Console Monitoring

### 5.1 Tail Utility

Use a second PowerShell process (or AI shell session):

```powershell
Get-Content -Path .\logs\headless_run.log -Wait | ForEach-Object {
    $_
    if ($_ -match 'ERROR:') {
        # Emit structured JSON for AI agent
        "AI_EVENT::error::$_"
    }
}
```

AI agents watch for `AI_EVENT::error` to trigger remediation steps.

### 5.2 Structured Parser (optional)

A lightweight Python watcher (invoked by AI) can categorize errors:

```python
import re, sys
ERROR_PATTERNS = {
    'parse_error': re.compile(r'Parse Error:'),
    'load_fail': re.compile(r'Failed to load script')
}
for line in sys.stdin:
    print(line, end='')
    for key, pat in ERROR_PATTERNS.items():
        if pat.search(line):
            print(f"AI_EVENT::error::{key}::{line.strip()}")
            sys.stdout.flush()
```

Run via `python watch_godot_log.py < logs\headless_run.log`.

---

## 6. Automated Test Configuration

### 6.1 Built-In Godot Test Runner

```
& $GODOT_EXE --headless --path .\capstone --run-tests --test TAP res://tests > logs\tests.tap 2>&1
```

- `--run-tests` executes Godot's native unit tests (if present).  
- `--test TAP` outputs TAP format (easy to parse).  
- AI tailer parses `logs\tests.tap` for failures.

### 6.2 Custom Integration Scripts

Create `res://scripts/HeadlessTestRunner.gd` to orchestrate gameplay scenarios. Example snippet:

```gdscript
extends SceneTree

func _init():
    var errors = []
    # Load main scene, simulate actions, gather metrics
    # ...
    if errors.is_empty():
        print("HEADLESS_PASS")
    else:
        for err in errors:
            push_error(err)
    quit()
```

Launch with `--script res://scripts/HeadlessTestRunner.gd`.

---

## 7. Error Detection & Auto-Remediation Workflow

### 7.1 Recommended Regex Patterns

| Pattern | Meaning | Action |
|------|---------|-----|
| `Parse Error:` | Compilation failure | Open offending file, correct syntax. |
| `Failed to load script` | Missing dependency or syntax error | Validate import paths or re-run parser. |
| `ERROR: In GVFS` | Missing resources | Ensure `.import` files or assets exist. |
| `Condition "!is_inside_tree" is true.` | Node lifecycle bug | Add guards before use. |

Implementation: AI tail process tags lines and selects remediation recipes (edit file, re-run command, etc.).

### 7.2 Restart Strategy

- Manual loop: `Stop-Process -Id <pid>` to halt the current run, apply fixes, and relaunch with updated arguments.
- Automated loop: `powershell.exe -NoProfile -File .\scripts\run_godot_headless.ps1 -LoopUntilSuccess -MaxAttempts 5 -RestartDelaySeconds 3` reruns until the exit code is 0 and no critical errors are detected.
- WSL/Git Bash loop: `LOOP_UNTIL_SUCCESS=1 MAX_ATTEMPTS=5 bash ./scripts/run_godot_headless.sh` offers the same behavior.

### 7.3 Error Summary Hooks

- Snapshot the latest run with `python .\scripts\watch_godot_log.py .\logs\headless_run.log --once --json`.
- Feed the JSON summary back into your agent to select remediation recipes per error `type`.
- Persist log artifacts (e.g., `logs/headless_run.log`) when handing context to another AI or a human developer.

---

## 8. Game State & Visual Testing (Optional)

Windows lacks a built-in screenshot flag for headless runs, but you can:

- Launch with `--headless --rendering-driver opengl3` and a custom script to capture viewport textures to PNG.
- Invoke `ViewportTexture.get_data().save_png("user://captures/frame.png")` within the test script.

AI agents retrieve images from `%APPDATA%\Godot\app_userdata\Capstone\captures`.

---

## 9. Integration with AI Development Environments

### 9.1 Claude Code / Open Interpreter

- Grant shell access.
- Configure reusable commands (e.g., `/godot headless`, `/godot tail`).
- Persist `$env:GODOT_EXE` in session for reuse.

### 9.2 Codex CLI (current environment)

- Use `powershell.exe -NoProfile -Command` invocations.
- Ensure the console executable lives within accessible directories (repo, tools folder, or absolute path).
- Define helper scripts in `scripts/` (already partially present) so the AI can call them by filename.

### 9.3 CI/CD (GitHub Actions, etc.)

- Add a Windows runner job with the console build cached.
- Use `actions/cache` to store the `Godot_v4.4.1-stable_win64_console.exe` binary.
- Run integration tests via PowerShell steps and upload logs/artifacts on failure.

---

## 10. Troubleshooting Quick Reference

| Symptom | Fix |
|---------|-----|
| **Console output empty** | Use console build, verify redirection (`*>` vs `*>>`). |
| **Editor opens GUI** | Missing `--headless` or wrong executable. |
| **Parse errors** | Tail log, apply fixes, re-run. Ensure scripts use Godot syntax (`? :`). |
| **Process hangs** | Confirm `--quit-on-finish` or send `Stop-Process`. |
| **File path issues** | Use absolute Windows paths, wrap in quotes. |

---

## 11. Suggested Next Steps

- [ ] Place the console executable under `tools/` or document its system path for the automation scripts.
- [x] Add `scripts/run_godot_headless.ps1` and `scripts/run_godot_headless.sh` for Windows and WSL runners.
- [x] Teach AI agents to launch and monitor via the new scripts (see Section 12 for loop pseudo-code).
- [ ] Extend `capstone/docs/Logging.md` with a Windows headless section referencing this guide.
- [ ] Port the macOS visual testing harness by scripting PNG captures in Godot.

---

**Document Version:** 0.9  
**Last Updated:** September 22, 2025  
**Author:** Auto-generated by Codex CLI  
**Scope:** Windows adaptation of macOS headless automation blueprint





 -match 'Parse Error:') {
        "AI_EVENT::error::raw::# Headless Godot Testing System for Windows

**Platform**: Windows 10/11  
**Engine**: Godot 4.4.1 (Win64 Console build)  
**Integration Target**: CLI-first AI agents (Claude Code, Open Interpreter, Codex CLI)  
**Status**: Draft Implementation Guide

---
## Implementation Status (2025-09-22)

- [x] `scripts/run_godot_headless.ps1` - automated launch/tail/error classification with optional restart loop
- [x] `scripts/run_godot_headless.sh` - WSL/Git Bash parity runner
- [x] `scripts/watch_godot_log.py` - standalone log follower emitting `AI_EVENT` markers
- [ ] Expand Windows-specific auto-fix recipes (next iteration)


## 1. Executive Summary

This guide adapts the macOS headless automation pipeline to Windows. It shows how to launch Godot headlessly from the console, capture its stdout/stderr for AI parsing, and orchestrate iterative build/test/debug cycles entirely through automation. The design assumes:

- The Godot **console** executable is available (e.g. `Godot_v4.4.1-stable_win64_console.exe`).
- AI agents can execute PowerShell/Bash commands in the project directory.
- Logs must land in predictable files so the agent can tail them and respond to failures.

---

## 2. Component Overview

| Component | Windows Equivalent | Notes |
|-----------|-------------------|-------|
| Direct executable access | Full path to `Godot_v4.4.1-stable_win64_console.exe` | No PATH edits required. |
| Background process manager | PowerShell `Start-Process` with `-PassThru` | Supports non-blocking runs and termination. |
| Console monitor | `Get-Content -Wait` or `Get-CimInstance Win32_Process` | Streams logs to agent for parsing. |
| Error detection engine | Regex filters (PowerShell / Python) | Look for `ERROR:` / `Parse Error:` patterns. |
| Test harness | `--headless`, `--run`, `--quit`, `--path` | Works for unit tests, scenes, or scripts. |
| Screenshot capture (optional) | `--headless --export-pack` or `--capture` (export template) | Requires GPUless run-skip if not needed. |

---

## 3. Direct Executable Access Layer

### 3.1 Locate Console Build

Recommended install location:

```
C:\Tools\Godot\Godot_v4.4.1-stable_win64_console\Godot_v4.4.1-stable_win64_console.exe
```

Alternative locations:

- `%ProgramFiles%\Godot\Godot_v4.4.1\Godot_v4.4.1-stable_win64_console.exe`
- Repository-local copy in `tools/`

> **Why console build?** Standard GUI builds suppress stdout until exit. The console build streams logs live, which is mandatory for automated parsing.

### 3.2 Launch Parameters

```
& $GODOT_EXE --headless --path C:\repo\capstone\capstone --verbose --quit-on-finish --script res://scripts/HeadlessTestRunner.gd
```

Key flags:

- `--headless` - disables window creation (CI-friendly).
- `--path <project>` - points to folder with `project.godot`.
- `--verbose` - emits detailed log lines (parser-friendly).
- `--quit-on-finish` - exits automatically after script/test run.
- `--script` or `--run <scene>` - entry point for tests/integration flows.

---

## 4. Background Process Management

### 4.1 Automated Runner Script

`scripts/run_godot_headless.ps1` wraps the Windows console build and now handles logging, live tailing, error classification, and optional retry loops.

```powershell
# one-shot launch with defaults
powershell.exe -NoProfile -File .\scripts\run_godot_headless.ps1 `
  -GodotPath "C:\\Tools\\Godot\\Godot_v4.4.1-stable_win64_console\\Godot_v4.4.1-stable_win64_console.exe"

# restart automatically until success (max 5 attempts)
powershell.exe -NoProfile -File .\scripts\run_godot_headless.ps1 `
  -LoopUntilSuccess -MaxAttempts 5 `
  -ExtraArgs @('--headless','--verbose','--quit-on-finish','--run-tests')
```

**Default behavior:**
- Launches with `--path <project>` plus entries from `-ExtraArgs`
- Streams `./logs/headless_run.log` to stdout (disable with `-NoTail`)
- Emits `AI_EVENT::error::<type>::...` for critical patterns (Parse Error, Failed to load script, File not found, Invalid call, Condition "...")
- Parses the log on exit and prints a JSON summary (suppress with `-SilentSummary`)
- Records a simple timeline for downstream tooling

**Example summary output:**

```json
{
  "success": false,
  "attempts": 1,
  "log_file": "C:\\Users\\jinph\\Documents\\00_Repositories\\capstone\\logs\\headless_run.log",
  "errors": [
    {
      "type": "missing_file",
      "message": "ERROR: Failed loading resource: res://utilities/sprite_manager.gd"
    }
  ],
  "timeline": [
    "[2025-09-22T05:14:02.6180000] Started Godot (PID 12345)",
    "[2025-09-22T05:14:03.1100000] Godot exited with code 1"
  ]
}
```

### 4.2 WSL/Git Bash Runner

`./scripts/run_godot_headless.sh` mirrors the PowerShell runner for WSL or Git Bash environments. It tails the same log, emits `AI_EVENT` markers, and returns a JSON summary.

```bash
GODOT_PATH="/mnt/c/Tools/Godot/.../Godot_v4.4.1-stable_win64_console.exe" \
PROJECT_PATH="$(wslpath 'C:\\Users\\jinph\\Documents\\00_Repositories\\capstone\\capstone')" \
LOOP_UNTIL_SUCCESS=1 MAX_ATTEMPTS=5 \
bash ./scripts/run_godot_headless.sh
```

Set `NO_TAIL=1` to suppress live output or override `LOG_FILE` for alternate runs.

### 4.3 Termination

```
Stop-Process -Id $pid -Force
```

Use this when you need to abort a hung process manually; the runner scripts automatically clean up their own tails.

---

## 5. Live Console Monitoring

### 5.1 Tail Utility

Use a second PowerShell process (or AI shell session):

```powershell
Get-Content -Path .\logs\headless_run.log -Wait | ForEach-Object {
    $_
    if ($_ -match 'ERROR:') {
        # Emit structured JSON for AI agent
        "AI_EVENT::error::$_"
    }
}
```

AI agents watch for `AI_EVENT::error` to trigger remediation steps.

### 5.2 Structured Parser (optional)

A lightweight Python watcher (invoked by AI) can categorize errors:

```python
import re, sys
ERROR_PATTERNS = {
    'parse_error': re.compile(r'Parse Error:'),
    'load_fail': re.compile(r'Failed to load script')
}
for line in sys.stdin:
    print(line, end='')
    for key, pat in ERROR_PATTERNS.items():
        if pat.search(line):
            print(f"AI_EVENT::error::{key}::{line.strip()}")
            sys.stdout.flush()
```

Run via `python watch_godot_log.py < logs\headless_run.log`.

---

## 6. Automated Test Configuration

### 6.1 Built-In Godot Test Runner

```
& $GODOT_EXE --headless --path .\capstone --run-tests --test TAP res://tests > logs\tests.tap 2>&1
```

- `--run-tests` executes Godot's native unit tests (if present).  
- `--test TAP` outputs TAP format (easy to parse).  
- AI tailer parses `logs\tests.tap` for failures.

### 6.2 Custom Integration Scripts

Create `res://scripts/HeadlessTestRunner.gd` to orchestrate gameplay scenarios. Example snippet:

```gdscript
extends SceneTree

func _init():
    var errors = []
    # Load main scene, simulate actions, gather metrics
    # ...
    if errors.is_empty():
        print("HEADLESS_PASS")
    else:
        for err in errors:
            push_error(err)
    quit()
```

Launch with `--script res://scripts/HeadlessTestRunner.gd`.

---

## 7. Error Detection & Auto-Remediation Workflow

### 7.1 Recommended Regex Patterns

| Pattern | Meaning | Action |
|------|---------|-----|
| `Parse Error:` | Compilation failure | Open offending file, correct syntax. |
| `Failed to load script` | Missing dependency or syntax error | Validate import paths or re-run parser. |
| `ERROR: In GVFS` | Missing resources | Ensure `.import` files or assets exist. |
| `Condition "!is_inside_tree" is true.` | Node lifecycle bug | Add guards before use. |

Implementation: AI tail process tags lines and selects remediation recipes (edit file, re-run command, etc.).

### 7.2 Restart Strategy

- Manual loop: `Stop-Process -Id <pid>` to halt the current run, apply fixes, and relaunch with updated arguments.
- Automated loop: `powershell.exe -NoProfile -File .\scripts\run_godot_headless.ps1 -LoopUntilSuccess -MaxAttempts 5 -RestartDelaySeconds 3` reruns until the exit code is 0 and no critical errors are detected.
- WSL/Git Bash loop: `LOOP_UNTIL_SUCCESS=1 MAX_ATTEMPTS=5 bash ./scripts/run_godot_headless.sh` offers the same behavior.

### 7.3 Error Summary Hooks

- Snapshot the latest run with `python .\scripts\watch_godot_log.py .\logs\headless_run.log --once --json`.
- Feed the JSON summary back into your agent to select remediation recipes per error `type`.
- Persist log artifacts (e.g., `logs/headless_run.log`) when handing context to another AI or a human developer.

---

## 8. Game State & Visual Testing (Optional)

Windows lacks a built-in screenshot flag for headless runs, but you can:

- Launch with `--headless --rendering-driver opengl3` and a custom script to capture viewport textures to PNG.
- Invoke `ViewportTexture.get_data().save_png("user://captures/frame.png")` within the test script.

AI agents retrieve images from `%APPDATA%\Godot\app_userdata\Capstone\captures`.

---

## 9. Integration with AI Development Environments

### 9.1 Claude Code / Open Interpreter

- Grant shell access.
- Configure reusable commands (e.g., `/godot headless`, `/godot tail`).
- Persist `$env:GODOT_EXE` in session for reuse.

### 9.2 Codex CLI (current environment)

- Use `powershell.exe -NoProfile -Command` invocations.
- Ensure the console executable lives within accessible directories (repo, tools folder, or absolute path).
- Define helper scripts in `scripts/` (already partially present) so the AI can call them by filename.

### 9.3 CI/CD (GitHub Actions, etc.)

- Add a Windows runner job with the console build cached.
- Use `actions/cache` to store the `Godot_v4.4.1-stable_win64_console.exe` binary.
- Run integration tests via PowerShell steps and upload logs/artifacts on failure.

---

## 10. Troubleshooting Quick Reference

| Symptom | Fix |
|---------|-----|
| **Console output empty** | Use console build, verify redirection (`*>` vs `*>>`). |
| **Editor opens GUI** | Missing `--headless` or wrong executable. |
| **Parse errors** | Tail log, apply fixes, re-run. Ensure scripts use Godot syntax (`? :`). |
| **Process hangs** | Confirm `--quit-on-finish` or send `Stop-Process`. |
| **File path issues** | Use absolute Windows paths, wrap in quotes. |

---

## 11. Suggested Next Steps

- [ ] Place the console executable under `tools/` or document its system path for the automation scripts.
- [x] Add `scripts/run_godot_headless.ps1` and `scripts/run_godot_headless.sh` for Windows and WSL runners.
- [x] Teach AI agents to launch and monitor via the new scripts (see Section 12 for loop pseudo-code).
- [ ] Extend `capstone/docs/Logging.md` with a Windows headless section referencing this guide.
- [ ] Port the macOS visual testing harness by scripting PNG captures in Godot.

---

**Document Version:** 0.9  
**Last Updated:** September 22, 2025  
**Author:** Auto-generated by Codex CLI  
**Scope:** Windows adaptation of macOS headless automation blueprint





"
    }
}
```

---

## 6. Automated Test Configuration

### 6.1 Built-In Godot Test Runner

```
& $GODOT_EXE --headless --path .\capstone --run-tests --test TAP res://tests > logs\tests.tap 2>&1
```

- `--run-tests` executes Godot's native unit tests (if present).  
- `--test TAP` outputs TAP format (easy to parse).  
- AI tailer parses `logs\tests.tap` for failures.

### 6.2 Custom Integration Scripts

Create `res://scripts/HeadlessTestRunner.gd` to orchestrate gameplay scenarios. Example snippet:

```gdscript
extends SceneTree

func _init():
    var errors = []
    # Load main scene, simulate actions, gather metrics
    # ...
    if errors.is_empty():
        print("HEADLESS_PASS")
    else:
        for err in errors:
            push_error(err)
    quit()
```

Launch with `--script res://scripts/HeadlessTestRunner.gd`.

---

## 7. Error Detection & Auto-Remediation Workflow

### 7.1 Recommended Regex Patterns

| Pattern | Meaning | Action |
|------|---------|-----|
| `Parse Error:` | Compilation failure | Open offending file, correct syntax. |
| `Failed to load script` | Missing dependency or syntax error | Validate import paths or re-run parser. |
| `ERROR: In GVFS` | Missing resources | Ensure `.import` files or assets exist. |
| `Condition "!is_inside_tree" is true.` | Node lifecycle bug | Add guards before use. |

Implementation: AI tail process tags lines and selects remediation recipes (edit file, re-run command, etc.).

### 7.2 Restart Strategy

- Manual loop: `Stop-Process -Id <pid>` to halt the current run, apply fixes, and relaunch with updated arguments.
- Automated loop: `powershell.exe -NoProfile -File .\scripts\run_godot_headless.ps1 -LoopUntilSuccess -MaxAttempts 5 -RestartDelaySeconds 3` reruns until the exit code is 0 and no critical errors are detected.
- WSL/Git Bash loop: `LOOP_UNTIL_SUCCESS=1 MAX_ATTEMPTS=5 bash ./scripts/run_godot_headless.sh` offers the same behavior.

### 7.3 Error Summary Hooks

- Snapshot the latest run with `python .\scripts\watch_godot_log.py .\logs\headless_run.log --once --json`.
- Feed the JSON summary back into your agent to select remediation recipes per error `type`.
- Persist log artifacts (e.g., `logs/headless_run.log`) when handing context to another AI or a human developer.

---

## 8. Game State & Visual Testing (Optional)

Windows lacks a built-in screenshot flag for headless runs, but you can:

- Launch with `--headless --rendering-driver opengl3` and a custom script to capture viewport textures to PNG.
- Invoke `ViewportTexture.get_data().save_png("user://captures/frame.png")` within the test script.

AI agents retrieve images from `%APPDATA%\Godot\app_userdata\Capstone\captures`.

---

## 9. Integration with AI Development Environments

### 9.1 Claude Code / Open Interpreter

- Grant shell access.
- Configure reusable commands (e.g., `/godot headless`, `/godot tail`).
- Persist `$env:GODOT_EXE` in session for reuse.

### 9.2 Codex CLI (current environment)

- Use `powershell.exe -NoProfile -Command` invocations.
- Ensure the console executable lives within accessible directories (repo, tools folder, or absolute path).
- Define helper scripts in `scripts/` (already partially present) so the AI can call them by filename.

### 9.3 CI/CD (GitHub Actions, etc.)

- Add a Windows runner job with the console build cached.
- Use `actions/cache` to store the `Godot_v4.4.1-stable_win64_console.exe` binary.
- Run integration tests via PowerShell steps and upload logs/artifacts on failure.

---

## 10. Troubleshooting Quick Reference

| Symptom | Fix |
|---------|-----|
| **Console output empty** | Use console build, verify redirection (`*>` vs `*>>`). |
| **Editor opens GUI** | Missing `--headless` or wrong executable. |
| **Parse errors** | Tail log, apply fixes, re-run. Ensure scripts use Godot syntax (`? :`). |
| **Process hangs** | Confirm `--quit-on-finish` or send `Stop-Process`. |
| **File path issues** | Use absolute Windows paths, wrap in quotes. |

---

## 11. Suggested Next Steps

- [ ] Place the console executable under `tools/` or document its system path for the automation scripts.
- [x] Add `scripts/run_godot_headless.ps1` and `scripts/run_godot_headless.sh` for Windows and WSL runners.
- [x] Teach AI agents to launch and monitor via the new scripts (see Section 12 for loop pseudo-code).
- [ ] Extend `capstone/docs/Logging.md` with a Windows headless section referencing this guide.
- [ ] Port the macOS visual testing harness by scripting PNG captures in Godot.

## 12. Claude/Codex Autonomous Loop Example

1. **Launch the runner** from the project root:

   ```python
   launch = Bash(
       command="powershell.exe -NoProfile -File .\\scripts\\run_godot_headless.ps1 -LoopUntilSuccess -MaxAttempts 3",
       run_in_background=True
   )
   headless_id = launch["bash_id"]
   ```

2. **Poll for events** while the process runs:

   ```python
   while True:
       output = BashOutput(bash_id=headless_id)
       if "AI_EVENT::error" in output["stdout"]:
           break
       if output["status"] != "running":
           break
   ```

3. **Collect structured errors** for remediation planning:

   ```python
   summary = Bash(command="python .\\scripts\\watch_godot_log.py .\\logs\\headless_run.log --once --json")
   parsed = json.loads(summary["stdout"] or "{\"errors\": []}")
   ```

4. **Apply fixes** with `Edit()` / `MultiEdit()` based on `parsed["errors"]` and note changes in the commit plan.

5. **Restart the cycle** when manual control is needed:

   ```python
   KillBash(shell_id=headless_id)
   headless_id = Bash(
       command="powershell.exe -NoProfile -File .\\scripts\\run_godot_headless.ps1 -LoopUntilSuccess -MaxAttempts 3",
       run_in_background=True
   )["bash_id"]
   ```

6. **Declare success** once the runner summary reports `"success": true` and the latest log scan finds no critical errors.

---

**Document Version:** 0.9  
**Last Updated:** September 22, 2025  
**Author:** Auto-generated by Codex CLI  
**Scope:** Windows adaptation of macOS headless automation blueprint















