# Local parity test — MySQL 9.7 LTS — 2026-11-03

Result: PASSED. Evidence: `local-test-evidence-2026-11-03.json`.

## What ran

The official MySQL 9.7.4 generic Linux tarball, run locally with the
test script in `scripts/local-test.sh`. There is no Docker in this VM,
so the binary ran directly: initialize insecure, set a runtime
generated root password, run the checks, stop, restart, verify again.

## Checks passed

- Version is 9.7.4 (`SELECT VERSION()`).
- Authenticated round-trip: create database, create table, insert a
  row, read it back (`parity-ok`).
- Unauthenticated connection rejected.
- Wrong password rejected.
- Restart persistence: the row survived a full stop and start.

## Environment quirks found (all in the test harness, not the template)

- The tarball's mysqld needs `libaio.so.1`; Ubuntu noble ships
  `libaio.so.1t64`, so the harness links the old soname to the new
  library under `tools/syslibs`.
- The test datadir MUST live on /tmp (tmpfs) on this VM. On the
  workspace (overlayfs) a first start after initialize fails with
  "Can't create UNDO tablespace ... already exists". Verified by a
  controlled experiment: same flow works on /tmp and fails on
  overlayfs, with both full and plain options. /tmp is only 512M and
  a datadir needs ~200M, so the script removes stale runs first and
  the datadir on success.
- mysqld refuses to run as root without `--user`; the script passes
  it. `innodb_log_file_size` was removed in MySQL 9, so the script
  does not set it.

## Still untested

- Live Railway deploy of this template. That waits for a paid Railway
  plan to be active, and the README is updated when it passes.
