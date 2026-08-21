# ============================================================================
# SmartPOS Database - Reset (drop + recreate + full setup) (PowerShell)
# ----------------------------------------------------------------------------
# DANGER: Drops the entire SmartPOS database (ALL DATA IS LOST) after an
# interactive confirmation, then re-runs the full setup (setup_database.ps1).
#
# Connection settings come EXCLUSIVELY from Configuration\.env (or
# Configuration\database.env as a fallback).
#
# Usage:
#     .\reset_database.ps1
#     .\reset_database.ps1 -EnvFile "Configuration\database.env"
#
# Exit codes: 0 = success, 1 = cancelled or any failure.
# ============================================================================

[CmdletBinding()]
param(
    [string]$EnvFile = ""
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$DbRoot  = Split-Path -Parent $ScriptDir
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
        Write-Host '[..] Using Invoke-Sqlcmd (SqlServer module).'
        return
    }
    $script:SqlcmdExe = if ($env:SQLCMD_BINARY) { $env:SQLCMD_BINARY } else { 'sqlcmd' }
    $resolved = Get-Command $script:SqlcmdExe -ErrorAction SilentlyContinue
    if (-not $resolved) {
        throw "sqlcmd ('$script:SqlcmdExe') was not found on PATH. Install SQL Server Command Line Utilities."
    }
    Write-Host "[..] Using sqlcmd.exe: $($resolved.Source)"
}

function Invoke-SqlQuery {
    param([string]$Query)
    $server  = Get-DbServer
    $timeout = if ($env:SQLCMD_TIMEOUT) { [int]$env:SQLCMD_TIMEOUT } else { 60 }
    if ($script:UseSqlcmdModule) {
        $params = @{
            ServerInstance = $server
            Database       = 'master'
            Query          = $Query
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
    $args = @('-S', $server, '-d', 'master', '-b', '-I', '-l', "$timeout")
    if (Test-TrustedConnection) { $args += '-E' } else { $args += @('-U', $env:DB_USERNAME, '-P', $env:DB_PASSWORD) }
    $args += @('-Q', $Query)
    & $script:SqlcmdExe @args | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd query failed (exit code $LASTEXITCODE)." }
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

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "  WARNING - THIS WILL DESTROY ALL DATA"
    Write-Host "  The database '$($env:DB_NAME)' on $(Get-DbServer) will be DROPPED and recreated."
    Write-Host "============================================================"
    Write-Host ""

    $confirm = Read-Host "Type RESET to continue"
    if ($confirm -ne 'RESET') {
        Write-Host '[..] Confirmation did not match. Aborting - nothing was changed.'
        exit 1
    }

    Initialize-SqlRunner

    Write-Host ""
    Write-Host "[..] Dropping database '$($env:DB_NAME)' ..."
    Invoke-SqlQuery -Query "IF DB_ID(N'$($env:DB_NAME)') IS NOT NULL BEGIN ALTER DATABASE [$($env:DB_NAME)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$($env:DB_NAME)]; END;"
    Write-Host "[OK]  Database '$($env:DB_NAME)' dropped."

    Write-Host ""
    Write-Host '[..] Re-running full setup ...'
    & (Join-Path $ScriptDir 'setup_database.ps1') -EnvFile $EnvFile
    exit $LASTEXITCODE
}
catch {
    Write-Host "[ERROR] Reset FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
