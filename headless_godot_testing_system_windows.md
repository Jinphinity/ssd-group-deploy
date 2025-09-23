# Headless Godot Testing System for Windows

**Platform**: Windows 10/11  
**Engine**: Godot 4.4.1 (Win64 Console build)  
**Integration Target**: CLI-first AI agents (Claude Code, Open Interpreter, Codex CLI)  
**Status**: Draft Implementation Guide

---

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
| Screenshot capture (optional) | `--headless --export-pack` or `--capture` (export template) | Requires GPUless run—skip if not needed. |

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

- `--headless` — disables window creation (CI-friendly).
- `--path <project>` — points to folder with `project.godot`.
- `--verbose` — emits detailed log lines (parser-friendly).
- `--quit-on-finish` — exits automatically after script/test run.
- `--script` or `--run <scene>` — entry point for tests/integration flows.

---

## 4. Background Process Management

### 4.1 Non-Blocking Run Helper

`scripts/run_godot_headless.ps1` (suggested location) can wrap `Start-Process`:

```powershell
param(
    [string]$GodotPath = "$env:ProgramFiles\Godot\Godot_v4.4.1\Godot_v4.4.1-stable_win64_console.exe",
    [string]$ProjectPath = (Resolve-Path "$PSScriptRoot\..\capstone"),
    [string]$LogFile = (Join-Path (Resolve-Path "$PSScriptRoot\..") "logs\headless_run.log"),
    [string[]]$Arguments = @('--headless', '--quit-on-finish', '--verbose')
)

if (-not (Test-Path $GodotPath)) { throw "Godot executable not found at $GodotPath" }

$logDir = Split-Path $LogFile
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

$fullArgs = @('--path', $ProjectPath) + $Arguments

$process = Start-Process -FilePath $GodotPath -ArgumentList $fullArgs -RedirectStandardOutput $LogFile -RedirectStandardError $LogFile -PassThru

"Godot started (PID $($process.Id)). Tailing log: $LogFile"
return $process.Id
```

AI agents can run this with custom `$Arguments` (e.g., `--run-tests`).

### 4.2 Termination

```
Stop-Process -Id $pid -Force
```

Claude/Open Interpreter can store `PID` for restarts.

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

- `--run-tests` executes Godot’s native unit tests (if present).  
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
|---------|---------|--------|
| `Parse Error:` | Compilation failure | Open offending file, correct syntax. |
| `Failed to load script` | Missing dependency or syntax error | Validate import paths or re-run parser. |
| `ERROR: In GVFS` | Missing resources | Ensure `.import` files or assets exist. |
| `Condition "!is_inside_tree" is true.` | Node lifecycle bug | Add guards before use. |

Implementation: AI tail process tags lines and selects remediation recipes (edit file, re-run command, etc.).

### 7.2 Restart Strategy

1. Stop process (`Stop-Process`).
2. Apply patch (e.g., via CLI editing).
3. Relaunch `run_godot_headless.ps1`.
4. Resume tailing logs.

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

1. Place the console executable under `tools/` or document its system path.
2. Add `scripts/run_godot_headless.ps1` and a matching `.sh` for WSL/MinGW users.
3. Teach your AI agent to run two commands:
   - Launch headless with redirection.
   - Tail and parse `.\logs\headless_run.log`.
4. Extend the existing `capstone/docs/Logging.md` with a Windows headless section referencing this guide.
5. (Optional) Port the macOS visual testing harness—requires writing Godot script to save captures.

---

**Document Version:** 0.9  
**Last Updated:** September 22, 2025  
**Author:** Auto-generated by Codex CLI  
**Scope:** Windows adaptation of macOS headless automation blueprint
