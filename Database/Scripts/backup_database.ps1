# ============================================================================
# SmartPOS Database - Full Backup (PowerShell)
# ----------------------------------------------------------------------------
# Takes a full, compressed BACKUP DATABASE of $env:DB_NAME to %BACKUP_DIR% with
# a timestamped filename, then purges backups older than BACKUP_KEEP_DAYS.
#
# Connection settings come EXCLUSIVELY from Configuration\.env (or
# Configuration\database.env as a fallback).
#
# Usage:
#     .\backup_database.ps1
#     .\backup_database.ps1 -EnvFile "Configuration\database.env"
#
# Exit codes: 0 = success, 1 = any failure.
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
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd backup query failed (exit code $LASTEXITCODE)." }
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

    # --- resolve backup directory (relative values anchored to Database root) ---
    $backupDir = $env:BACKUP_DIR
    if ([string]::IsNullOrWhiteSpace($backupDir)) { $backupDir = 'Backup' }
    if (-not [System.IO.Path]::IsPathRooted($backupDir)) { $backupDir = Join-Path $DbRoot $backupDir }
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    $ts         = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupFile = Join-Path $backupDir ("{0}_{1}.bak" -f $env:DB_NAME, $ts)
    $keepDays   = if ($env:BACKUP_KEEP_DAYS) { [int]$env:BACKUP_KEEP_DAYS } else { 14 }

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " SmartPOS Database Backup"
    Write-Host " Target: $(Get-DbServer) / $($env:DB_NAME)"
    Write-Host " Output: $backupFile"
    Write-Host "============================================================"
    Write-Host ""

    Write-Host '[..] Running BACKUP DATABASE ... (this may take a moment)'
    Invoke-SqlQuery -Query "BACKUP DATABASE [$($env:DB_NAME)] TO DISK = N'$backupFile' WITH INIT, NAME = N'$($env:DB_NAME)-Full-$ts', COMPRESSION, STATS = 10;"

    $size = (Get-Item -Path $backupFile).Length
    Write-Host "[OK]  Backup created: $backupFile ($([math]::Round($size / 1MB, 2)) MB)"

    # --- retention: purge backups older than BACKUP_KEEP_DAYS -------------------
    Write-Host "[..] Purging backups older than $keepDays days ..."
    $cutoff = (Get-Date).AddDays(-$keepDays)
    $removed = 0
    Get-ChildItem -Path $backupDir -Filter '*.bak' -File | Where-Object { $_.LastWriteTime -lt $cutoff } | ForEach-Object {
        Remove-Item -Path $_.FullName -Force
        Write-Host "[..] Removed old backup: $($_.Name)"
        $removed++
    }
    if ($removed -eq 0) { Write-Host '[OK]  No old backups to purge.' }

    Write-Host '[OK]  Backup completed successfully.'
}
catch {
    Write-Host "[ERROR] Backup FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
