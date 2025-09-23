param (
    [string]$GodotPath = "$env:ProgramFiles\Godot\Godot.exe",
    [string]$ProjectPath = (Resolve-Path "$PSScriptRoot\..\capstone"),
    [string]$LogPath = (Join-Path (Resolve-Path "$PSScriptRoot\..") "logs\godot_editor.log")
)

if (-not (Test-Path $GodotPath)) {
    Write-Error "Godot executable not found at '$GodotPath'. Pass -GodotPath to this script with your install location."
    exit 1
}

if (-not (Test-Path $ProjectPath)) {
    Write-Error "Project path '$ProjectPath' does not exist."
    exit 1
}

$logDir = Split-Path $LogPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

Write-Host "Starting Godot editor..." -ForegroundColor Cyan
Write-Host "  Godot executable : $GodotPath"
Write-Host "  Project path     : $ProjectPath"
Write-Host "  Log file         : $LogPath"

$arguments = @("-e", "--path", $ProjectPath, "--verbose")
$process = Start-Process -FilePath $GodotPath \
    -ArgumentList $arguments \
    -RedirectStandardOutput $LogPath \
    -RedirectStandardError $LogPath \
    -PassThru

Write-Host "Godot editor launched (PID $($process.Id))."
Write-Host "Tailing command: Get-Content -Path '$LogPath' -Wait"

$process.WaitForExit()

Write-Host "Godot editor has exited with code $($process.ExitCode)." -ForegroundColor Yellow
