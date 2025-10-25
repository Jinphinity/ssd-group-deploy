# Godot Editor with Logging - Windows PowerShell
# Captures editor stdout/stderr to logs/godot_editor.log for CLI agent access

param(
    [string]$GodotPath = "C:\Program Files\Godot\Godot_v4.4-stable_win64.exe",
    [string]$ProjectPath = $PWD.Path
)

# Configuration
$LogDir = "logs"
$LogFile = Join-Path $LogDir "godot_editor.log"

Write-Host "🎮 Godot Editor with Logging" -ForegroundColor Blue
Write-Host "================================" -ForegroundColor Blue

# Validate Godot installation
if (-not (Test-Path $GodotPath)) {
    Write-Host "❌ Godot not found at: $GodotPath" -ForegroundColor Red
    Write-Host "💡 Specify correct path with -GodotPath parameter" -ForegroundColor Yellow
    Write-Host "   Example: .\run_editor_with_logging.ps1 -GodotPath 'C:\Godot\Godot.exe'" -ForegroundColor Yellow
    exit 1
}

# Create logs directory
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

# Initialize log file with session header
$SessionHeader = @"
=================================================
Godot Editor Session Started: $(Get-Date)
Project Path: $ProjectPath
Godot Path: $GodotPath
=================================================
"@
Add-Content -Path $LogFile -Value $SessionHeader

Write-Host "✅ Godot found: $GodotPath" -ForegroundColor Green
Write-Host "✅ Logging to: $LogFile" -ForegroundColor Green
Write-Host "📝 Monitor logs in another terminal:" -ForegroundColor Yellow
Write-Host "   Get-Content -Path $LogFile -Wait" -ForegroundColor Blue
Write-Host ""
Write-Host "🚀 Starting Godot Editor..." -ForegroundColor Yellow

# Function to handle cleanup on script exit
function Cleanup {
    $SessionFooter = @"

=================================================
Godot Editor Session Ended: $(Get-Date)
=================================================
"@
    Add-Content -Path $LogFile -Value $SessionFooter
    Write-Host ""
    Write-Host "📝 Editor session logged to: $LogFile" -ForegroundColor Yellow
}

# Set up cleanup
try {
    # Change to project directory
    Push-Location $ProjectPath

    # Launch Godot editor with logging
    # 2>&1 captures both stdout and stderr
    # Tee-Object appends to log file while showing output
    & $GodotPath --editor --path $ProjectPath 2>&1 | Tee-Object -FilePath $LogFile -Append
}
catch {
    Write-Host "❌ Error launching Godot: $_" -ForegroundColor Red
}
finally {
    Pop-Location
    Cleanup
}