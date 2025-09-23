# Logging Guide

This project captures Godot editor/runtime logs in two complementary ways so CLI tooling can read them without relying on the Godot UI output panel.

## 1. Built-in File Logging (Runtime)
- `project.godot` enables file logging under the `[logging]` section.
- Runtime logs are written to `user://logs/capstone_runtime.log` (e.g., `%APPDATA%\Godot\app_userdata\Capstone\logs\capstone_runtime.log` on Windows).
- You can tail the file directly with `Get-Content -Wait "$env:APPDATA\Godot\app_userdata\Capstone\logs\capstone_runtime.log"` (PowerShell) or `tail -f "$HOME/.local/share/godot/app_userdata/Capstone/logs/capstone_runtime.log"` on Linux/macOS.

## 2. Launch Scripts that Redirect stdout/stderr (Editor)
Two helper scripts in `scripts/` start the editor and stream console output into `logs/godot_editor.log` inside the repository:

- Windows PowerShell: `scripts/run_editor_with_logging.ps1`
  ```powershell
  # Update -GodotPath if your install lives elsewhere
  .\scripts\run_editor_with_logging.ps1 -GodotPath "C:\\Program Files\\Godot\\Godot_v4.4-stable_win64.exe"
  # Follow the log in another terminal
  Get-Content -Path .\logs\godot_editor.log -Wait
  ```
- macOS/Linux: `scripts/run_editor_with_logging.sh`
  ```bash
  # Set GODOT_PATH if Godot is not on PATH or in the default location
  GODOT_PATH=/Applications/Godot.app/Contents/MacOS/Godot ./scripts/run_editor_with_logging.sh
  # Follow the log in another terminal
  tail -f logs/godot_editor.log
  ```

Both scripts append to the same repo-local file so you can keep a running history and share it with the CLI agent.

## Log Locations Recap
- Runtime log: `user://logs/capstone_runtime.log` (per-user Godot data directory)
- Editor/stdout log: `logs/godot_editor.log` (repo-relative)

`.gitignore` already covers the `logs/` directory; keep it that way unless you intend to commit generated logs.
