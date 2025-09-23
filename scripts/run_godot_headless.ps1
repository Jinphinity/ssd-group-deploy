param (
    [string]$GodotPath = "$env:ProgramFiles\Godot\Godot_v4.4.1\Godot_v4.4.1-stable_win64_console.exe",
    [string]$ProjectPath = (Resolve-Path "$PSScriptRoot\..\capstone"),
    [string]$LogFile = (Join-Path (Resolve-Path "$PSScriptRoot\..") "logs\headless_run.log"),
    [string[]]$ExtraArgs = @('--headless', '--verbose', '--quit-on-finish'),
    [switch]$LoopUntilSuccess,
    [int]$MaxAttempts = 3,
    [int]$RestartDelaySeconds = 2,
    [switch]$NoTail,
    [switch]$SilentSummary
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $GodotPath)) {
    throw "Godot executable not found at '$GodotPath'. Set -GodotPath to the console build executable."
}

if (-not (Test-Path $ProjectPath)) {
    throw "Project path '$ProjectPath' does not exist."
}

$logDir = Split-Path -Path $LogFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$baseArgs = @('--path', $ProjectPath)
$timeline = @()

$errorPatterns = @(
    @{ Type = 'parse_error'; Pattern = 'Parse Error:'; Severity = 'critical'; Hint = 'Fix the GDScript syntax or missing type declarations.' },
    @{ Type = 'load_fail'; Pattern = 'Failed to load script'; Severity = 'critical'; Hint = 'Check resource paths and ensure dependencies compile.' },
    @{ Type = 'missing_file'; Pattern = 'File not found'; Severity = 'critical'; Hint = 'Restore the missing file or update references.' },
    @{ Type = 'runtime_function'; Pattern = 'Invalid call'; Severity = 'high'; Hint = 'Confirm the target node or method exists before calling.' },
    @{ Type = 'runtime_assert'; Pattern = 'Condition "'; Severity = 'high'; Hint = 'Investigate the runtime assertion and guard against invalid states.' }
)

$attempt = 0
$success = $false
$errorReport = @()

function Invoke-GodotHeadless {
    param(
        [string]$CurrentLogFile,
        [System.Collections.Hashtable]$PatternTable,
        [switch]$DisableTail
    )

    $process = Start-Process -FilePath $GodotPath -ArgumentList ($baseArgs + $ExtraArgs) -RedirectStandardOutput $CurrentLogFile -RedirectStandardError $CurrentLogFile -PassThru

    $timeline += "[$(Get-Date -Format o)] Started Godot (PID $($process.Id))"

    $tailJob = $null
    if (-not $DisableTail) {
        while (-not (Test-Path $CurrentLogFile)) {
            if ($process.HasExited) { break }
            Start-Sleep -Milliseconds 200
        }

        if (Test-Path $CurrentLogFile) {
            $tailJob = Start-Job -ScriptBlock {
                param($LogPath, $PatternData)
                $compiledPatterns = @()
                foreach ($item in $PatternData) {
                    $compiledPatterns += [pscustomobject]@{
                        Type = $item.Type
                        Regex = [regex]::new($item.Pattern)
                    }
                }

                Get-Content -Path $LogPath -Wait | ForEach-Object {
                    $line = $_
                    Write-Output $line

                    foreach ($pattern in $compiledPatterns) {
                        if ($pattern.Regex.IsMatch($line)) {
                            Write-Output ("AI_EVENT::error::{0}::{1}" -f $pattern.Type, ($line.Trim()))
                            break
                        }
                    }
                }
            } -ArgumentList $CurrentLogFile, $PatternTable
        }
    }

    $process.WaitForExit()
    $timeline += "[$(Get-Date -Format o)] Godot exited with code $($process.ExitCode)"

    if ($tailJob) {
        try {
            Stop-Job -Job $tailJob -Force -ErrorAction SilentlyContinue
            Receive-Job -Job $tailJob -ErrorAction SilentlyContinue | Out-Null
        } finally {
            Remove-Job -Job $tailJob -Force -ErrorAction SilentlyContinue
        }
    }

    return $process.ExitCode
}

while ($true) {
    $attempt += 1
    if (Test-Path $LogFile) {
        Remove-Item -Path $LogFile -Force
    }

    Write-Host "=== Headless Godot Attempt $attempt ==="
    $exitCode = Invoke-GodotHeadless -CurrentLogFile $LogFile -PatternTable $errorPatterns -DisableTail:$NoTail

    Start-Sleep -Seconds 1

    $logLines = @()
    if (Test-Path $LogFile) {
        $logLines = Get-Content -Path $LogFile -ErrorAction SilentlyContinue
    }

    $iterationErrors = @()
    foreach ($line in $logLines) {
        foreach ($pattern in $errorPatterns) {
            if ($line -match $pattern.Pattern) {
                $iterationErrors += [pscustomobject]@{
                    type = $pattern.Type
                    severity = $pattern.Severity
                    message = $line.Trim()
                    hint = $pattern.Hint
                }
                break
            }
        }
    }

    if ($iterationErrors.Count -eq 0 -and $exitCode -eq 0) {
        $success = $true
        break
    }

    $errorReport += [pscustomobject]@{
        attempt = $attempt
        exit_code = $exitCode
        errors = $iterationErrors
    }

    if (-not $LoopUntilSuccess -or $attempt -ge $MaxAttempts) {
        break
    }

    Write-Host "Encountered errors. Applying LoopUntilSuccess retry (attempt $attempt of $MaxAttempts)." -ForegroundColor Yellow
    Start-Sleep -Seconds $RestartDelaySeconds
}

$result = [pscustomobject]@{
    success = $success
    attempts = $attempt
    log_file = $LogFile
    timestamp = (Get-Date -Format o)
    errors = $errorReport
    timeline = $timeline
}

if (-not $SilentSummary) {
    Write-Host "=== Headless Run Summary ==="
    $result | ConvertTo-Json -Depth 6
}

if ($success) {
    exit 0
}

exit 1
