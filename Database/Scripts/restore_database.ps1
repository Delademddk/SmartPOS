# ============================================================================
# SmartPOS Database - Restore from Full Backup (PowerShell)
# ----------------------------------------------------------------------------
# Restores the SmartPOS database from a .bak file. If the database already
# exists you MUST pass -Replace, otherwise the restore is refused.
#
# Connection settings come EXCLUSIVELY from Configuration\.env (or
# Configuration\database.env as a fallback).
#
# Usage:
#     .\restore_database.ps1 -BackupFile "Database\Backup\SmartPOS_20260807_143000.bak"
#     .\restore_database.ps1 -BackupFile "C:\backups\SmartPOS_prod.bak" -Replace
#
# Relative paths are resolved against the Database root folder.
# Exit codes: 0 = success, 1 = any failure.
# ============================================================================

[CmdletBinding()]
param(
    [string]$BackupFile = "",
    [switch]$Replace,
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
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd restore query failed (exit code $LASTEXITCODE)." }
}

function Test-DatabaseExists {
    param([string]$Name)
    $server  = Get-DbServer
    $timeout = if ($env:SQLCMD_TIMEOUT) { [int]$env:SQLCMD_TIMEOUT } else { 60 }
    if ($script:UseSqlcmdModule) {
        $params = @{
            ServerInstance = $server
            Database       = 'master'
            Query          = "SET NOCOUNT ON; SELECT COUNT(*) AS [C] FROM sys.databases WHERE name = N'$Name';"
            ErrorAction    = 'Stop'
        }
        if (-not (Test-TrustedConnection)) {
            $params.Username = $env:DB_USERNAME
            $params.Password = $env:DB_PASSWORD
        }
        $row = Invoke-Sqlcmd @params
        return ([int]$row.C) -gt 0
    }
    $args = @('-S', $server, '-d', 'master', '-b', '-I', '-h', '-1', '-W')
    if (Test-TrustedConnection) { $args += '-E' } else { $args += @('-U', $env:DB_USERNAME, '-P', $env:DB_PASSWORD) }
    $args += @('-Q', "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = N'$Name';")
    $out = @(& $script:SqlcmdExe @args)
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd query failed (exit code $LASTEXITCODE)." }
    if ($out.Count -eq 0) { return $false }
    return ([int]($out[0] | Out-String).Trim()) -gt 0
}

try {
    if ([string]::IsNullOrWhiteSpace($BackupFile)) {
        Write-Host "Usage: .\restore_database.ps1 -BackupFile <path-to-.bak> [-Replace]"
        Write-Host ""
        Write-Host "  -BackupFile  Path to the backup file to restore."
        Write-Host "  -Replace     Overwrite an existing SmartPOS database."
        exit 1
    }

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

    # --- resolve the backup file path (relative to Database root) ---------------
    $bak = $BackupFile
    if (-not [System.IO.Path]::IsPathRooted($bak)) { $bak = Join-Path $DbRoot $bak }
    if (-not (Test-Path $bak)) { throw "Backup file not found: $bak" }

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " SmartPOS Database Restore"
    Write-Host " Target: $(Get-DbServer) / $($env:DB_NAME)"
    Write-Host " Backup: $bak"
    Write-Host "============================================================"
    Write-Host ""

    # --- refuse to overwrite an existing database without -Replace --------------
    if (Test-DatabaseExists -Name $env:DB_NAME) {
        if (-not $Replace) {
            throw "Database '$($env:DB_NAME)' already exists. Re-run with -Replace to overwrite it."
        }
        Write-Host "[..] Database '$($env:DB_NAME)' exists - restoring with REPLACE."
    }

    $replaceClause = if ($Replace) { 'REPLACE ' } else { '' }
    Write-Host '[..] Running RESTORE DATABASE ... (this may take a moment)'
    Invoke-SqlQuery -Query "IF DB_ID(N'$($env:DB_NAME)') IS NOT NULL ALTER DATABASE [$($env:DB_NAME)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; RESTORE DATABASE [$($env:DB_NAME)] FROM DISK = N'$bak' WITH $replaceClause RECOVERY; ALTER DATABASE [$($env:DB_NAME)] SET MULTI_USER;"

    Write-Host "[OK]  Database '$($env:DB_NAME)' restored from '$bak'."
}
catch {
    Write-Host "[ERROR] Restore FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
