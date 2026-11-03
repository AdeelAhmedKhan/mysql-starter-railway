# MySQL 9.7 LTS — Single-Node Database Template for Railway

Single-node MySQL 9.7 LTS on the official image, ready to deploy on
Railway. No app code, no replica set, no backups. Just a database
with auth on and a persistent volume.

## Why this template exists

Railway's own MySQL template still pins mysql:8, and as of 2026-11-03
there is no standalone MySQL 9 template on the marketplace. The only
MySQL 9.7.4 on the marketplace is bundled inside the Mautic app
template, not a database you can point your own app at. This template
fills that gap with the current LTS line.

## Deploy

1. Deploy the template from the Railway marketplace (search
   "MySQL 9.7 LTS").
2. Save the generated root password shown once at deploy time.
3. Connect from another service in the same project with MYSQL_URL,
   or from outside with a TCP proxy.

## Who this is for

- You want MySQL 9.7 LTS on Railway without running the upgrade
  yourself.
- You want a plain database for your app, not a bundle.
- You are fine managing one node: backups and failover are yours
  to add.

## Exact Composer settings

- Image: mysql:9.7.4
- Type: database
- Port: 3306, private networking only (no public networking)
- Volume: /var/lib/mysql
- Restart: ON_FAILURE
- Start command: docker-entrypoint.sh mysqld (the image default)

## Variables

- MYSQL_ROOT_PASSWORD: generated at deploy time. The root account.
  Never commit a real value.
- MYSQL_DATABASE: optional. Created on first start when set.
- MYSQL_USER / MYSQL_PASSWORD: optional app user, created on first
  start only when both are set.
- MYSQL_URL, MYSQLHOST, MYSQLPORT, MYSQLUSER, MYSQLPASSWORD,
  MYSQLDATABASE: Railway reference variables, added by the composer
  for other services in the same project.

## Connection

From another service in the same Railway project, use MYSQL_URL.
From your machine, use a TCP proxy and connect to 127.0.0.1 with the
root user and the generated password. The default auth plugin is
caching_sha2_password.

## Honest scope

- Verified locally 2026-11-03: version 9.7.4, authenticated
  connection, table round-trip, unauthenticated rejection, wrong
  password rejection, restart persistence. See
  docs/local-test-2026-11-03.md.
- Live Railway deploy: NOT tested. That stays untested until a paid
  Railway plan is active, and this section is updated when it passes.

## Not included

- Replication / high availability / automatic failover
- Backups (snapshot the volume or run mysqldump on a schedule)
- App code or drivers

## Support scope

If you change the image tag, the database is yours to manage,
including upgrades. Upgrading an existing MySQL 8 volume to 9.7 is
not a tag swap: use a dump and restore, or follow MySQL's documented
upgrade path.
