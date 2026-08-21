#!/usr/bin/env bash
# ============================================================================
# SmartPOS Database - Test Suite Runner
# ----------------------------------------------------------------------------
# Executes Testing/00..12 in order using sqlcmd -b (stop on error).
# Reads connection settings from Database/Configuration/.env (see
# database.env.example). All suites are non-destructive (transactional,
# rolled back) EXCEPT the auto-commit phase of 06_security_roles which fully
# cleans up after itself.
#
# Usage:
#   ./run_tests.sh            # uses Configuration/.env values
#   ./run_tests.sh -d OtherDB # override the database name
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$DB_DIR/Configuration/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: $ENV_FILE not found. Copy database.env.example to .env first." >&2
    exit 1
fi

DB_NAME="${DB_NAME:-SmartPOS}"

# --- parse .env (ignore comments and blanks) --------------------------------
get() { sed -n "s/^$1=//p" "$ENV_FILE" | tail -n1; }

HOST="$(get DB_HOST)";            HOST="${HOST:-localhost}"
PORT="$(get DB_PORT)";            PORT="${PORT:-1433}"
INSTANCE="$(get DB_INSTANCE)"
USER="$(get DB_USERNAME)";        USER="${USER:-sa}"
PASS="$(get DB_PASSWORD)"
SQLCMD="$(get SQLCMD_BINARY)";    SQLCMD="${SQLCMD:-sqlcmd}"
TIMEOUT="$(get SQLCMD_TIMEOUT)";  TIMEOUT="${TIMEOUT:-60}"

while getopts "d:h" opt; do
    case "$opt" in
        d) DB_NAME="$OPTARG" ;;
        h) echo "Usage: $0 [-d database]"; exit 0 ;;
        *) exit 2 ;;
    esac
done

if [[ -z "$PASS" ]]; then
    echo "ERROR: DB_PASSWORD is empty in $ENV_FILE" >&2
    exit 1
fi

if [[ -n "$INSTANCE" ]]; then
    SERVER="$HOST\\$INSTANCE"
else
    SERVER="$HOST,$PORT"
fi

echo "==> Target: $SERVER / $DB_NAME"
echo "==> SQLCMD : $(command -v "$SQLCMD" || echo "(using $SQLCMD)")"

# --- run each suite in order ------------------------------------------------
fail=0
for f in "$SCRIPT_DIR"/0[0-9]_*.sql "$SCRIPT_DIR"/1[0-2]_*.sql; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f")"
    printf '==> Running %s ... ' "$name"
    if "$SQLCMD" -S "$SERVER" -U "$USER" -P "$PASS" -d "$DB_NAME" \
        -b -l "$TIMEOUT" -i "$f" >/tmp/smartpos_test_$$.log 2>&1; then
        echo "PASS"
    else
        echo "FAIL"
        echo "    --- sqlcmd output ---"
        sed 's/^/    /' /tmp/smartpos_test_$$.log | tail -n 30
        rm -f /tmp/smartpos_test_$$.log
        fail=1
        break
    fi
done
rm -f /tmp/smartpos_test_$$.log

if [[ "$fail" -ne 0 ]]; then
    echo "==> One or more suites FAILED." >&2
    exit 1
fi
echo "==> All suites passed."
