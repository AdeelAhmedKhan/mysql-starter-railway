#!/usr/bin/env bash
# Local parity test for the MySQL 9.7 LTS template.
# Uses a local mysqld 9.7.4 from ~/workspace/tools/mysql-9.7.4 (official
# generic Linux tarball). No Docker required. The root password is
# generated at runtime and never written to the repo; it only lives in
# this process. Writes JSON evidence to docs/.
set -euo pipefail

BASE="${MYSQL_BASE:-$HOME/workspace/tools/mysql-9.7.4}"
MYSQLD="$BASE/bin/mysqld"
MYSQL="$BASE/bin/mysql"
MYSQLADMIN="$BASE/bin/mysqladmin"
# Local libaio for the generic tarball (Ubuntu noble ships libaio.so.1t64;
# the tarball's mysqld wants the libaio.so.1 soname — see tools/syslibs).
SYSLIBS="$HOME/workspace/tools/syslibs/usr/lib/x86_64-linux-gnu"
if [ -d "$SYSLIBS" ]; then
  export LD_LIBRARY_PATH="$SYSLIBS${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVIDENCE="$ROOT/docs/local-test-evidence-2026-11-03.json"

for bin in "$MYSQLD" "$MYSQL" "$MYSQLADMIN"; do
  [ -x "$bin" ] || { echo "missing binary: $bin (download the 9.7.4 tarball into $BASE first)"; exit 1; }
done

PORT="${MYSQL_TEST_PORT:-33307}"
# NOTE: the datadir MUST live on /tmp (tmpfs) on this VM. The workspace
# sits on overlayfs, and a first start after --initialize-insecure
# fails there with "Can't create UNDO tablespace ... already exists"
# (verified: same flow works on /tmp, fails on overlayfs, with both
# full and plain options). /tmp is only 512M and a datadir needs
# ~200M, so remove stale runs first and the datadir on success.
rm -rf /tmp/mysql-parity-*
DATADIR="$(mktemp -d /tmp/mysql-parity-XXXXXX)"
SOCKET="$DATADIR/mysql.sock"
LOG="$DATADIR/mysqld.log"
mkdir -p "$ROOT/docs"

stop_server() {
  if [ -n "${TEST_PASS:-}" ]; then
    "$MYSQLADMIN" --socket="$SOCKET" -u root -p"$TEST_PASS" shutdown 2>/dev/null || true
  else
    "$MYSQLADMIN" --socket="$SOCKET" -u root shutdown 2>/dev/null || true
  fi
  for _ in $(seq 1 30); do
    [ -S "$SOCKET" ] || return 0
    sleep 1
  done
  return 0
}
cleanup() { stop_server; }
trap cleanup EXIT

echo "initializing datadir $DATADIR"
"$MYSQLD" --initialize-insecure --user="$(whoami)" --datadir="$DATADIR" --log-error="$DATADIR/init.log"

start_server() {
  "$MYSQLD" --datadir="$DATADIR" --socket="$SOCKET" --port="$PORT" \
    --bind-address=127.0.0.1 --user="$(whoami)" --pid-file="$DATADIR/mysqld.pid" \
    --innodb-buffer-pool-size=64M \
    --key-buffer-size=8M --max-connections=20 --performance-schema=OFF \
    --disable-log-bin --log-error="$LOG" &
  for _ in $(seq 1 60); do
    if [ -n "${TEST_PASS:-}" ]; then
      if "$MYSQLADMIN" --socket="$SOCKET" -u root -p"$TEST_PASS" ping --silent 2>/dev/null; then return 0; fi
    elif "$MYSQLADMIN" --socket="$SOCKET" -u root ping --silent 2>/dev/null; then return 0
    fi
    sleep 1
  done
  echo "mysqld did not become ready"; tail -30 "$LOG"; exit 1
}

start_server
VERSION="$("$MYSQL" --socket="$SOCKET" -u root -N -e "SELECT VERSION();")"
echo "version: $VERSION"
case "$VERSION" in
  9.7.4*) ;;
  *) echo "unexpected version: $VERSION"; exit 1 ;;
esac

TEST_PASS="$(openssl rand -hex 16)"
"$MYSQL" --socket="$SOCKET" -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$TEST_PASS';"

export MYSQL_SOCKET="$SOCKET" MYSQL_USER="root" MYSQL_PASS="$TEST_PASS" MYSQL_BIN="$MYSQL"
"$ROOT/scripts/roundtrip.sh"

echo "checking unauthenticated rejection"
if "$MYSQL" --socket="$SOCKET" -u root -e "SELECT 1;" 2>/dev/null; then
  echo "FAIL: unauthenticated connection succeeded"; exit 1
else
  echo "unauthenticated rejected"
fi
if "$MYSQL" --socket="$SOCKET" -u root -p"wrongpassword" -e "SELECT 1;" 2>/dev/null; then
  echo "FAIL: wrong password accepted"; exit 1
else
  echo "wrong password rejected"
fi

echo "restarting for persistence check"
stop_server
start_server
"$ROOT/scripts/roundtrip.sh" verify-only
stop_server

cat > "$EVIDENCE" <<EOF
{
  "template": "MySQL 9.7 LTS",
  "image": "mysql:9.7.4",
  "date": "2026-11-03",
  "version": "$VERSION",
  "checks": {
    "version_is_9.7.4": true,
    "authenticated_roundtrip": true,
    "unauthenticated_rejected": true,
    "wrong_password_rejected": true,
    "restart_persistence": true
  },
  "still_untested": ["Live Railway deploy"]
}
EOF
echo "evidence written to $EVIDENCE"
rm -rf "$DATADIR"
echo "PARITY TEST PASSED"
