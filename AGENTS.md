# AGENTS.md — working in this repo

Read this before changing anything. This is a bare database template,
not an app. Keep it minimal, pinned, and honest.

## Stack (pinned — do not bump majors casually)

- MySQL **9.7.4**, official `mysql:9.7.4` image. 9.7 is the current
  LTS line (GA 21 Apr 2026). Never pin an innovation release
  (9.0–9.6 are short lived; 9.6 is already deprecated and
  unavailable) and never pin `mysql:latest` or `mysql:9` — a moving
  tag is not a trust signal.
- No app code, no driver, no framework lives here. The only code is
  the local parity test in `scripts/`.

## The one rule that matters

**Never fake a capability.** A health check that cannot reach the
database is a failure, even if the process is running. A test that did
not run is "not tested", not a pass. A live Railway deploy that has
not happened is "untested", not "proven". Say exactly which of these
is true in the README and in every test report.

## Layout

- `README.md` — template description, exact Composer settings,
  variables, connection string, honest scope.
- `railway-template.json` — transcription of the exact Template
  Composer settings for publishing. Railway does NOT read this file
  automatically; it exists so the published template can be reviewed
  and reproduced exactly.
- `docker-compose.yml` — local equivalent of the Composer settings
  (same image, volume path, variable names). Requires Docker; the
  parity test script does not.
- `.env.example` — variable names only, placeholders only. Never put
  a real password here, in tests, or in example files.
- `scripts/local-test.sh` — starts a local `mysqld` 9.7.4, sets a
  runtime generated root password, runs the round-trip, checks
  unauthenticated rejection and restart persistence, stops the
  server, writes JSON evidence to `docs/`.
- `scripts/roundtrip.sh` — mysql client round-trip. Reads credentials
  from the environment only; it has no default password.
- `docs/local-test-2026-11-03.md` — the parity test report, written
  after the test passes.

## Publishing gate (from the railway_template_publishing skill)

1. Local parity test passes, with full command responses read.
2. Secret scan of the whole folder passes (no real passwords, keys,
   or tokens, including tests and example files).
3. Publish only then, and list what is still untested (live Railway
   deploy, until a paid plan is active) on the template page and in
   the README.
4. Never report a pass you did not see, and re-run the test yourself
   after any builder finishes before reporting it.
