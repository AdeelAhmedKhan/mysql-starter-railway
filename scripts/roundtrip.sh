#!/usr/bin/env bash
# MySQL round-trip for the parity test. Credentials come from the
# environment only (MYSQL_SOCKET, MYSQL_USER, MYSQL_PASS, MYSQL_BIN).
# It has no default password. With argument "verify-only" it only reads
# the row back (used after a restart); otherwise it creates and fills
# the probe table first.
set -euo pipefail
: "${MYSQL_SOCKET:?}" "${MYSQL_USER:?}" "${MYSQL_PASS:?}"
MYSQL_BIN="${MYSQL_BIN:-$HOME/workspace/tools/mysql-9.7.4/bin/mysql}"

run() {
  "$MYSQL_BIN" --socket="$MYSQL_SOCKET" -u"$MYSQL_USER" -p"$MYSQL_PASS" -N -e "$1" 2>/dev/null
}

if [ "${1:-}" != "verify-only" ]; then
  run "CREATE DATABASE IF NOT EXISTS parity_test;"
  run "DROP TABLE IF EXISTS parity_test.probe;"
  run "CREATE TABLE parity_test.probe (id INT PRIMARY KEY, val VARCHAR(64));"
  run "INSERT INTO parity_test.probe VALUES (1, 'parity-ok');"
fi

GOT="$(run "SELECT val FROM parity_test.probe WHERE id = 1;")"
[ "$GOT" = "parity-ok" ] || { echo "round-trip mismatch: got '$GOT'"; exit 1; }
echo "round-trip ok: $GOT"
