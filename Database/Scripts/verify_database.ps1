# ============================================================================
# SmartPOS Database - Test Suite Runner (PowerShell)
# ----------------------------------------------------------------------------
# Runs every Testing\NN_*.sql suite (00..12) in order and prints a PASS/FAIL
# summary. Exits non-zero if any suite fails. Uses Invoke-Sqlcmd when the
# SqlServer module is available, otherwise falls back to sqlcmd.exe.
#
# Connection settings come EXCLUSIVELY from Configuration\.env (or
# Configuration\database.env as a fallback).
#
# Usage:
#     .\verify_database.ps1
#     .\verify_database.ps1 -EnvFile "Configuration\database.env"
#
# Exit codes: 0 = all suites passed, 1 = one or more suites failed.
# ============================================================================

[CmdletBinding()]
param(
    [string]$EnvFile = ""
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$DbRoot  = Split-Path -Parent $ScriptDir
$TestDir = Join-Path $DbRoot 'Testing'
$ConfDir = Join-Path $DbRoot 'Configuration'

function Load-EnvFile {
    param([string]$Path)
    foreach ($line in Get-Content -Path $Path) {
        $t = $line.Trim()
        if ([string]::IsNullOrEmpty($t)) { continue }
        if ($t.StartsWith('#')) { continue }
        $eq = $t.IndexOf('=')
        if ($eq -lt 1) { continue }
        $key = $t.Substring(0, $eq).Trim()
        $val = $t.Substring($eq + 1).Trim()
        $hash = $val.IndexOf('#')
        if ($hash -ge 0) { $val = $val.Substring(0, $hash).TrimEnd() }
        [Environment]::SetEnvironmentVariable($key, $val, 'Process')
    }
}

function Get-DbServer {
    $hostName = $env:DB_HOST
    if ([string]::IsNullOrWhiteSpace($hostName)) { throw 'DB_HOST is not set in the environment file.' }
    if (-not [string]::IsNullOrWhiteSpace($env:DB_INSTANCE)) {
        return "$hostName\$($env:DB_INSTANCE)"
    }
    $port = if ($env:DB_PORT) { $env:DB_PORT } else { '1433' }
    return "$hostName,$port"
}

function Test-TrustedConnection {
    return $env:DB_TRUSTED_CONNECTION -in @('true', 'yes', '1')
}

$script:UseSqlcmdModule = $false
$script:SqlcmdExe       = $null

function Initialize-SqlRunner {
    if (Get-Command 'Invoke-Sqlcmd' -ErrorAction SilentlyContinue) {
        $script:UseSqlcmdModule = $true
        return
    }
    $script:SqlcmdExe = if ($env:SQLCMD_BINARY) { $env:SQLCMD_BINARY } else { 'sqlcmd' }
    $resolved = Get-Command $script:SqlcmdExe -ErrorAction SilentlyContinue
    if (-not $resolved) {
        throw "sqlcmd ('$script:SqlcmdExe') was not found on PATH. Install SQL Server Command Line Utilities."
    }
}

function Invoke-SqlFile {
    param([string]$Path)
    $server  = Get-DbServer
    $timeout = if ($env:SQLCMD_TIMEOUT) { [int]$env:SQLCMD_TIMEOUT } else { 60 }
    if ($script:UseSqlcmdModule) {
        $params = @{
            ServerInstance = $server
            Database       = $env:DB_NAME
            InputFile      = $Path
            QueryTimeout   = $timeout
            ErrorAction    = 'Stop'
        }
        if (-not (Test-TrustedConnection)) {
            $params.Username = $env:DB_USERNAME
            $params.Password = $env:DB_PASSWORD
        }
        Invoke-Sqlcmd @params | Out-Null
        return
    }
    $args = @('-S', $server, '-d', $env:DB_NAME, '-b', '-I', '-l', "$timeout")
    if (Test-TrustedConnection) { $args += '-E' } else { $args += @('-U', $env:DB_USERNAME, '-P', $env:DB_PASSWORD) }
    $args += @('-i', $Path)
    & $script:SqlcmdExe @args | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed on '$Path' (exit code $LASTEXITCODE)." }
}

try {
    if (-not $EnvFile) {
        $candidates = @((Join-Path $ConfDir '.env'), (Join-Path $ConfDir 'database.env'))
        $EnvFile = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $EnvFile -or -not (Test-Path $EnvFile)) {
        throw "Environment file not found. Expected Configuration\.env or Configuration\database.env."
    }

    Write-Host "[..] Loading environment from $EnvFile"
    Load-EnvFile -Path $EnvFile

    if (-not $env:DB_HOST) { throw 'DB_HOST is not set in the environment file.' }
    if (-not $env:DB_NAME) { throw 'DB_NAME is not set in the environment file.' }
    if (-not (Test-TrustedConnection)) {
        if (-not $env:DB_USERNAME) { throw 'DB_USERNAME is not set in the environment file.' }
        if (-not $env:DB_PASSWORD) { throw 'DB_PASSWORD is not set in the environment file.' }
    }

    Initialize-SqlRunner

    $files = @(Get-ChildItem -Path $TestDir -Filter '*.sql' -File |
        Where-Object { $_.Name -match '^0\d_|^1[0-2]_' } |
        Sort-Object Name)

    if ($files.Count -eq 0) {
        throw "No test suites found under $TestDir (expected Testing\00_*.sql .. 12_*.sql)."
    }

    $pass = 0
    $fail = 0
    $failed = @()

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " SmartPOS Test Suite  (target: $(Get-DbServer) / $($env:DB_NAME))"
    Write-Host "============================================================"

    foreach ($f in $files) {
        Write-Host "[..] Running $($f.Name) ... "
        try {
            Invoke-SqlFile -Path $f.FullName
            Write-Host "  PASS  $($f.Name)"
            $pass++
        }
        catch {
            Write-Host "  FAIL  $($f.Name): $($_.Exception.Message)"
            $failed += $f.Name
            $fail++
        }
    }

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " SUMMARY : PASS=$pass  FAIL=$fail"
    Write-Host "============================================================"

    if ($fail -gt 0) {
        Write-Host "[ERROR] One or more test suites FAILED: $($failed -join ', ')" -ForegroundColor Red
        exit 1
    }
    Write-Host '[OK]  All test suites passed.'
}
catch {
    Write-Host "[ERROR] Verification FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
