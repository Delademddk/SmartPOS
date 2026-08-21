# SmartPOS Database — Configuration Guide

**Document ID:** DOC-DB-CONFIG
**Version:** 1.0
**Status:** Approved
**Date:** August 7, 2026

Reference for every configuration file and environment variable used by the
SmartPOS database tooling (scripts, tests, backups) and for the connection
settings consumed by the application.

---

## 1. Configuration Folder

All runtime configuration lives in `Database/Configuration/`:

| File | Purpose | Committed? |
|------|---------|------------|
| `.env` | **Local runtime values** for your machine/server | **No — never commit.** Created from `.env.example`. |
| `database.env.example` | Template documenting every variable and its default | Yes |
| `connection.example.sql` | Sample `sqlcmd`/SSMS connection options | Yes |

The pattern mirrors the application repository: a template is committed, the
real `.env` is git-ignored and contains environment-specific secrets
(credentials, paths).

---

## 2. Environment Variables

Everything below is defined in `database.env.example` and read by the setup,
backup, restore and test scripts.

| Variable | Default | Used by | Purpose |
|----------|---------|---------|---------|
| `DB_HOST` | `localhost` | setup, backup, restore, tests | SQL Server host name or IP |
| `DB_PORT` | `1433` | all sqlcmd callers | SQL Server port |
| `DB_USERNAME` | `sa` | all sqlcmd callers | **Install-time** SQL login (see §4) |
| `DB_PASSWORD` | `ChangeMe_StrongPassword_2026` | all sqlcmd callers | **Placeholder — must change.** |
| `DB_NAME` | `SmartPOS` | all sqlcmd callers | Target database name |
| `DB_TRUSTED_CONNECTION` | `false` | all sqlcmd callers | `true` = Windows/integrated auth |
| `SQLCMD_BINARY` | `sqlcmd` | script wrappers | Path/name of the `sqlcmd` executable |
| `BACKUP_DIR` | `./Backup` | backup scripts | Where `.bak`/`.dif`/`.trn` files are written |
| `BACKUP_KEEP_DAYS` | `14` | backup scripts | Local retention for backup files |
| `DB_DEFAULT_COLLATION` | `SQL_Latin1_General_CP1_CI_AS` | setup | Database default collation |
| `DB_SCHEMA` | `dbo` | setup | Default schema for created objects |

### 2.1 Setting a variable

`.env` uses plain `KEY=value` lines (no spaces around `=`):

```bash
DB_HOST=10.0.0.25
DB_PORT=1433
DB_USERNAME=pos_app
DB_PASSWORD=CorrectHorseBatteryStaple!2026
DB_NAME=SmartPOS
DB_TRUSTED_CONNECTION=false
SQLCMD_BINARY=sqlcmd
BACKUP_DIR=D:\SQLBackups\SmartPOS
BACKUP_KEEP_DAYS=14
DB_DEFAULT_COLLATION=SQL_Latin1_General_CP1_CI_AS
DB_SCHEMA=dbo
```

Quoting values is allowed where the parser supports it; keep values free of
`#` (comments) and newlines.

### 2.2 How scripts consume `.env`

The wrapper scripts (`setup_database.*`, `backup_database.*`,
`restore_database.*`, `run_tests.sh`) source/load `Database/Configuration/.env`,
export the variables, and forward them to `sqlcmd` via connection flags:

```bash
sqlcmd -S "$DB_HOST,$DB_PORT" \
       -U "$DB_USERNAME" -P "$DB_PASSWORD" \
       -d "$DB_NAME" -i script.sql -b -e
```

When `DB_TRUSTED_CONNECTION=true`, the scripts omit `-U`/`-P` and use
`-E` (trusted/integrated authentication) instead.

---

## 3. Authentication Modes

| Mode | `DB_TRUSTED_CONNECTION` | Connection | Best for |
|------|--------------------------|------------|----------|
| SQL auth | `false` | `-U <login> -P <password>` | Standalone servers, POS clients on a private network |
| Windows / integrated | `true` | `-E` | Domain-joined environments with Kerberos |

- **SQL auth:** create the dedicated `pos_app` login (see
  [`SecurityGuide.md`](SecurityGuide.md) §3). Do **not** ship the `sa`
  placeholder password.
- **Windows auth:** the service account running the scripts must be a valid
  SQL login / member of the application role.

The application connection string equivalents are in §5.

---

## 4. Install vs Runtime Credentials

Two distinct credentials exist and must not be confused:

| Credential | Used for | Where stored |
|------------|----------|--------------|
| **Install/DBA login** (e.g. `sa` in the template) | Creating the database, running DDL, applying seed | `.env` during install only |
| **Application login** (`pos_app`) | POS application runtime — `EXECUTE`/`SELECT` only | Application secret store (env/secret manager) |

The `.env` `DB_USERNAME`/`DB_PASSWORD` defaults to the DBA account for
installation convenience. For **runtime**, the POS application must use the
least-privilege `pos_app` login from its own configuration, **not** the DBA
credentials. Change the `sa` placeholder password immediately after install
and prefer creating a dedicated DBA login.

---

## 5. Application Connection Strings

### 5.1 SQL authentication

```
Server=localhost,1433;Database=SmartPOS;User Id=pos_app;
Password=<from-secret-manager>;Encrypt=true;
TrustServerCertificate=true;Application Name=SmartPOS-POS
```

### 5.2 Windows authentication

```
Server=localhost,1433;Database=SmartPOS;Integrated Security=true;
Encrypt=true;TrustServerCertificate=true;Application Name=SmartPOS-POS
```

Use `Encrypt=true` in production. `TrustServerCertificate=true` is acceptable
only with a trusted certificate on the server; prefer `false` with a proper
TLS cert for highest security.

### 5.3 `connection.example.sql`

The sample shows the `sqlcmd` invocation form used throughout the tooling:

```sql
-- sqlcmd -S localhost,1433 -U <user> -P <password> -d SmartPOS -i connection.example.sql
:setvar SqlServerName "localhost,1433"
:setvar DatabaseName "SmartPOS"
PRINT 'Connected to $(SqlServerName), database $(DatabaseName)';
SELECT @@SERVERNAME AS server_name,
       DB_NAME()     AS database_name,
       SERVERPROPERTY('Collation') AS server_collation;
```

Use it to confirm connectivity and collation before installing.

---

## 6. Secrets Handling Rules

1. **Never commit `.env`.** The template `database.env.example` is the only
   config file committed; copy it locally with
   `cp database.env.example .env`.
2. **Rotate credentials:** change the placeholder `DB_PASSWORD` and the `sa`
   password at install; rotate the `pos_app` password on a schedule.
3. **Prefer a secret manager** for the application runtime password; `.env`
   is for the DBA tooling scripts.
4. **Restrict file permissions** on `.env` to the service account (e.g.
   `chmod 600` / NTFS ACLs).
5. Log files must never echo `-P` passwords — use `-P "$DB_PASSWORD"` (env
   expansion), never literal passwords in scheduled tasks or scripts.

---

## 7. Troubleshooting Configuration

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `Login failed for user 'sa'` | Wrong/placeholder password | Set real password in `.env`; verify login exists |
| `Cannot open server ... requested by the login is not supported` | Client/library version | Upgrade `sqlcmd`/ODBC driver |
| `A network-related or instance-specific error` | Host/port wrong, firewall | Check `DB_HOST`/`DB_PORT`; open 1433 |
| Collation mismatch errors | `DB_DEFAULT_COLLATION` differs from existing DB | Match the existing database collation |
| Scripts hang on auth | `DB_TRUSTED_CONNECTION` wrong for the environment | Set `true` for Windows auth, `false` for SQL auth |
| `.env` values ignored | Line format wrong / comments | Use `KEY=value` with no spaces; no `#` inside values |

---

## 8. Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-08-07 | Initial configuration guide |
