# ============================================================================
# SmartPOS Database - Full Setup (PowerShell)
# ----------------------------------------------------------------------------
# Creates the database if it does not exist, applies every SQL module in FK
# dependency order, seeds runtime data, then runs a final object-count
# verification. Uses Invoke-Sqlcmd when the SqlServer module is available,
# otherwise falls back to sqlcmd.exe.
#
# Connection settings come EXCLUSIVELY from Configuration\.env (or
# Configuration\database.env as a fallback). Never edit credentials here.
#
# Usage:
#     .\setup_database.ps1
#     .\setup_database.ps1 -EnvFile "Configuration\database.env"
#
# Optional behaviour:
#     $env:RUN_SAMPLE_DATA = "0"  # skip SampleData
#
# Exit codes: 0 = success, 1 = any failure (build aborted on first error).
# ============================================================================

[CmdletBinding()]
param(
    [string]$EnvFile = ""
)

$ErrorActionPreference = 'Stop'

# --- resolve paths relative to this script (repo path contains spaces) -------
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$DbRoot   = Split-Path -Parent $ScriptDir
$SqlDir   = Join-Path $DbRoot 'SQL'
$ConfDir  = Join-Path $DbRoot 'Configuration'

# --- helper: load KEY=VALUE lines from the environment file -------------------
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

# --- helper: server string ("host\instance" vs "host,port") --------------------
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

# --- runner selection ----------------------------------------------------------
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

# --- execute a query (no result set expected) -----------------------------------
function Invoke-SqlQuery {
    param(
        [string]$Query,
        [string]$Database = 'master'
    )
    $server  = Get-DbServer
    $timeout = if ($env:SQLCMD_TIMEOUT) { [int]$env:SQLCMD_TIMEOUT } else { 60 }
    if ($script:UseSqlcmdModule) {
        $params = @{
            ServerInstance = $server
            Database       = $Database
            Query          = $Query
            QueryTimeout   = $timeout
            ErrorAction    = 'Stop'
        }
        if (-not (Test-TrustedConnection)) {
            $params.Username = $env:DB_USERNAME
            $params.Password = $env:DB_PASSWORD
        }
        return @(Invoke-Sqlcmd @params)
    }
    $args = @('-S', $server, '-d', $Database, '-b', '-I', '-l', "$timeout")
    if (Test-TrustedConnection) { $args += '-E' } else { $args += @('-U', $env:DB_USERNAME, '-P', $env:DB_PASSWORD) }
    $args += @('-Q', $Query, '-h', '-1', '-W')
    $out = & $script:SqlcmdExe @args
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd query failed (exit code $LASTEXITCODE)." }
    return @($out)
}

# --- execute a SQL script file --------------------------------------------------
function Invoke-SqlFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "SQL file not found: $Path" }
    Write-Host "[RUN] $Path"
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
    }
    else {
        $args = @('-S', $server, '-d', $env:DB_NAME, '-b', '-I', '-l', "$timeout")
        if (Test-TrustedConnection) { $args += '-E' } else { $args += @('-U', $env:DB_USERNAME, '-P', $env:DB_PASSWORD) }
        $args += @('-i', $Path)
        & $script:SqlcmdExe @args
        if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed on '$Path' (exit code $LASTEXITCODE)." }
    }
    Write-Host "[OK]  $Path"
}

# --- check whether a database exists --------------------------------------------
function Test-DatabaseExists {
    param([string]$Name)
    $rows = Invoke-SqlQuery -Query "SET NOCOUNT ON; SELECT COUNT(*) AS [C] FROM sys.databases WHERE name = N'$Name';" -Database 'master'
    if ($rows.Count -eq 0) { return $false }
    $val = $rows[0]
    if ($val -is [pscustomobject] -or $val -is [System.Data.DataRow]) { $val = $val.C }
    return ([int]$val) -gt 0
}

# --- create the database if missing ----------------------------------------------
function New-DatabaseIfMissing {
    if (Test-DatabaseExists -Name $env:DB_NAME) {
        Write-Host "[OK]  Database '$($env:DB_NAME)' already exists - creation skipped."
        return
    }
    $collation = if ($env:DB_DEFAULT_COLLATION) { $env:DB_DEFAULT_COLLATION } else { 'SQL_Latin1_General_CP1_CI_AS' }
    Write-Host "[..] Creating database '$($env:DB_NAME)' ..."
    Invoke-SqlQuery -Query "IF DB_ID(N'$($env:DB_NAME)') IS NULL CREATE DATABASE [$($env:DB_NAME)] COLLATE $collation;" -Database 'master' | Out-Null
    Write-Host "[OK]  Database '$($env:DB_NAME)' created."
    try {
        Invoke-SqlQuery -Query "ALTER DATABASE [$($env:DB_NAME)] SET RECOVERY FULL; ALTER DATABASE [$($env:DB_NAME)] SET ALLOW_SNAPSHOT_ISOLATION ON; ALTER DATABASE [$($env:DB_NAME)] SET READ_COMMITTED_SNAPSHOT ON;" -Database 'master' | Out-Null
        Write-Host '[..] Recovery FULL + snapshot isolation configured.'
    }
    catch {
        Write-Host '[WARN] Could not apply recovery/snapshot settings - continuing anyway.'
    }
}

# ============================================================================
#  Main
# ============================================================================
try {
    if (-not $EnvFile) {
        $candidates = @((Join-Path $ConfDir '.env'), (Join-Path $ConfDir 'database.env'))
        $EnvFile = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $EnvFile -or -not (Test-Path $EnvFile)) {
        throw "Environment file not found. Expected Configuration\.env or Configuration\database.env (copy database.env.example first)."
    }

    Write-Host "[..] Loading environment from $EnvFile"
    Load-EnvFile -Path $EnvFile

    # --- defaults + validation --------------------------------------------------
    if (-not $env:DB_HOST) { throw 'DB_HOST is not set in the environment file.' }
    if (-not $env:DB_NAME) { throw 'DB_NAME is not set in the environment file.' }
    if (-not (Test-TrustedConnection)) {
        if (-not $env:DB_USERNAME) { throw 'DB_USERNAME is not set in the environment file.' }
        if (-not $env:DB_PASSWORD) { throw 'DB_PASSWORD is not set in the environment file.' }
    }
    $runSample = if ($env:RUN_SAMPLE_DATA) { $env:RUN_SAMPLE_DATA } else { '1' }

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " SmartPOS Database Setup"
    Write-Host " Target: $(Get-DbServer) / $($env:DB_NAME)"
    Write-Host "============================================================"
    Write-Host ""

    Initialize-SqlRunner

    # --- step 1: create database if missing -------------------------------------
    New-DatabaseIfMissing

    # --- step 2: apply SQL modules in FK dependency order -----------------------
    Write-Host ""
    Write-Host '[..] Applying SQL modules in dependency order ...'
    $sqlFiles = @(
        '17_Shared\functions.sql'
        '01_Authentication\tables.sql'
        '02_Users\tables.sql'
        '03_Business\tables.sql'
        '04_Categories\tables.sql'
        '06_Suppliers\tables.sql'
        '05_Products\tables.sql'
        '07_Inventory\tables.sql'
        '07_Inventory\SP_Inventory.sql'
        '08_Sales\tables.sql'
        '08_Sales\SP_CreateSale.sql'
        '09_Payments\tables.sql'
        '09_Payments\SP_Payments.sql'
        '10_CreditSales\tables.sql'
        '11_Returns\tables.sql'
        '11_Returns\SP_ProcessReturn.sql'
        '12_Notifications\tables.sql'
        '12_Notifications\SP_Notifications.sql'
        '15_Settings\tables.sql'
        '15_Settings\SP_Settings.sql'
        '16_Audit\tables.sql'
        '16_Audit\SP_Audit.sql'
        '01_Authentication\SP_Roles.sql'
        '01_Authentication\SP_Login.sql'
        '02_Users\SP_Users.sql'
        '03_Business\SP_Business.sql'
        '04_Categories\SP_Categories.sql'
        '05_Products\SP_Products.sql'
        '06_Suppliers\SP_Suppliers.sql'
        'Views\Core_Operational_Views.sql'
        '13_Reports\VW_Report_Views.sql'
        '13_Reports\SP_Reports.sql'
        '14_Dashboard\VW_Dashboard_Views.sql'
        '14_Dashboard\SP_Dashboard.sql'
        'Triggers\All_Triggers.sql'
    )
    foreach ($rel in $sqlFiles) {
        Invoke-SqlFile -Path (Join-Path $SqlDir $rel)
    }

    # --- step 3: record schema version, seed runtime data, then sample data -----
    Invoke-SqlFile -Path (Join-Path $SqlDir 'Migrations\001_baseline.sql')
    Invoke-SqlFile -Path (Join-Path $SqlDir 'SeedData\SeedData.sql')

    if ($runSample -in @('0', 'false', 'no')) {
        Write-Host '[..] RUN_SAMPLE_DATA is 0 - skipping SampleData.'
    }
    else {
        Invoke-SqlFile -Path (Join-Path $SqlDir 'SampleData\SampleData.sql')
    }

    # --- step 4: verify key objects ---------------------------------------------
    Write-Host ""
    Write-Host '[..] Verifying database objects ...'
    Invoke-SqlQuery -Database $env:DB_NAME -Query "SET NOCOUNT ON; SELECT 'tables' AS [object], COUNT(*) AS [count] FROM sys.tables UNION ALL SELECT 'views', COUNT(*) FROM sys.views UNION ALL SELECT 'procedures', COUNT(*) FROM sys.procedures UNION ALL SELECT 'functions', COUNT(*) FROM sys.objects WHERE type IN ('FN','IF','TF'); SELECT 'users' AS [object], COUNT(*) AS [count] FROM dbo.users;"

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "[OK] SmartPOS database setup completed successfully."
    Write-Host "============================================================"
}
catch {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "[ERROR] SmartPOS database setup FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "============================================================"
    exit 1
}
