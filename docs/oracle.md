---
layout: page
title: Oracle connections
permalink: /adapters/oracle
---

This page collects Oracle‑specific connection tips for Rokaki (and ActiveRecord in general), including environment variables, client library notes, and how to avoid common errors during local development and CI runs.

Rokaki uses ActiveRecord’s `oracle_enhanced` adapter and ruby‑oci8 under the hood. All examples below assume ActiveRecord 7.1–8.x as used by Rokaki.

## Quick start: commands that work

- Preferred full descriptor (stable across environments):

```bash
RBENV_VERSION=3.3.0 \
ORACLE_USERNAME=system ORACLE_PASSWORD=oracle \
NLS_LANG=AMERICAN_AMERICA.AL32UTF8 \
ORACLE_DATABASE='(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=FREEPDB1)))' \
bundle exec rspec spec/lib/04_oracle_aware_spec.rb --format documentation
```

- EZCONNECT (be sure to include the double slash prefix):

```bash
RBENV_VERSION=3.3.0 \
ORACLE_DATABASE=//127.0.0.1:1521/FREEPDB1 \
ORACLE_USERNAME=system ORACLE_PASSWORD=oracle \
NLS_LANG=AMERICAN_AMERICA.AL32UTF8 \
bundle exec rspec spec/lib/04_oracle_aware_spec.rb
```

Notes:
- Oracle Free images typically expose a pluggable database (PDB) service named `FREEPDB1`.
- Oracle XE images typically use `XEPDB1` instead.
- If you hit listener errors (ORA‑12514/12521), verify the exact service via `lsnrctl status` inside your container and confirm host port mapping.

## Environment variables Rokaki tests understand

The spec helper accepts overrides which are passed to ActiveRecord’s connection config (see `spec/support/database_manager.rb`):

- `ORACLE_HOST` — defaults to `localhost`
- `ORACLE_PORT` — defaults to `1521`
- `ORACLE_USERNAME` — database username
- `ORACLE_PASSWORD` — database password
- `ORACLE_DATABASE` — EZCONNECT or TNS/descriptor, takes precedence over `ORACLE_SERVICE_NAME`
- `ORACLE_SERVICE_NAME` — service name (e.g., `FREEPDB1` or `XEPDB1`)
- `NLS_LANG` — recommended: `AMERICAN_AMERICA.AL32UTF8`

If only `ORACLE_SERVICE_NAME` is provided, Rokaki’s test helper composes a full descriptor automatically. If `ORACLE_DATABASE` is provided, it is used as‑is (recommended for EZCONNECT or explicit descriptors).

## ruby‑oci8 and Instant Client

- Build‑time (already set in this repo’s `.bundle/config`):

```yaml
BUNDLE_BUILD__RUBY___OCI8: "--with-instant-client-dir=/opt/oracle/instantclient_23_3 \
  --with-instant-client-include=/opt/oracle/instantclient_23_3/sdk/include \
  --with-instant-client-lib=/opt/oracle/instantclient_23_3"
```

- Runtime (set these if the client libraries aren’t found or you see NLS errors):

macOS:
```bash
export DYLD_LIBRARY_PATH=/opt/oracle/instantclient_23_3:$DYLD_LIBRARY_PATH
```
Linux:
```bash
export LD_LIBRARY_PATH=/opt/oracle/instantclient_23_3:$LD_LIBRARY_PATH
```
Optional (explicit NLS data path):
```bash
export OCI_NLS10=/opt/oracle/instantclient_23_3/nls/data
```

## Common errors and fixes

- ORA‑12705: Cannot access NLS data files or invalid environment specified
  - Cause: invalid/missing NLS settings or client libraries not found.
  - Fix: set `NLS_LANG=AMERICAN_AMERICA.AL32UTF8` (or leave unset), ensure Instant Client libraries are on `DYLD_LIBRARY_PATH` (macOS) or `LD_LIBRARY_PATH` (Linux). Optionally set `OCI_NLS10`.

- ORA‑12514 / ORA‑12521: TNS:listener does not currently know of service requested in connect descriptor / service not registered
  - Cause: wrong `SERVICE_NAME`, wrong host/port, container not exposing the service.
  - Fix: run `lsnrctl status` inside the container; use the exact `SERVICE_NAME` (e.g., `FREEPDB1`), confirm host port mapping. For EZCONNECT, remember the `//` prefix: `//HOST:PORT/SERVICE`.

- ORA‑01017: invalid username/password; logon denied
  - Cause: wrong credentials for the target service/PDB.
  - Fix: double‑check username/password; for tests you can connect as `SYSTEM` to bootstrap schema, or create a dedicated test user (see below).

## Creating a dedicated test schema user

From `SYSTEM` (connected to the target PDB service):

```sql
CREATE USER ROKAKI IDENTIFIED BY rokaki;
GRANT CONNECT, RESOURCE, CREATE TABLE, CREATE SEQUENCE TO ROKAKI;
ALTER USER ROKAKI QUOTA UNLIMITED ON USERS;
```

Then connect with:

```bash
ORACLE_USERNAME=ROKAKI ORACLE_PASSWORD=rokaki \
ORACLE_DATABASE=//127.0.0.1:1521/FREEPDB1 \
NLS_LANG=AMERICAN_AMERICA.AL32UTF8 \
bundle exec rspec spec/lib/04_oracle_aware_spec.rb
```

## Rails `database.yml` examples

Using `oracle_enhanced` with service name:

```yaml
production:
  adapter: oracle_enhanced
  host: <%= ENV["ORACLE_HOST"] || "localhost" %>
  port: <%= (ENV["ORACLE_PORT"] || 1521).to_i %>
  username: <%= ENV["ORACLE_USERNAME"] %>
  password: <%= ENV["ORACLE_PASSWORD"] %>
  service_name: <%= ENV["ORACLE_SERVICE_NAME"] || "FREEPDB1" %>
```

Using EZCONNECT/descriptor directly:

```yaml
production:
  adapter: oracle_enhanced
  username: <%= ENV["ORACLE_USERNAME"] %>
  password: <%= ENV["ORACLE_PASSWORD"] %>
  database: <%= ENV["ORACLE_DATABASE"] %> # e.g., //127.0.0.1:1521/FREEPDB1
```

## CI and local tips

- Prefer the full `(DESCRIPTION=...)` form in CI to avoid resolver quirks.
- On Oracle Free containers the default service is `FREEPDB1`; on XE it’s `XEPDB1`.
- If your tests need to create tables, use a user with `CREATE TABLE` and `CREATE SEQUENCE` privileges (our specs do this automatically).
