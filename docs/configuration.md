---
layout: page
title: Configuration
permalink: /configuration
---

{% include lang_switcher.html %}

This page covers configuration, environment overrides, and tips for running the test suite across adapters.

## Environment variables

Rokaki's test helpers (used in the specs) support environment variable overrides for all adapters. These are useful when your local databases run on non‑default ports or hosts.

### SQL Server
- `SQLSERVER_HOST` (default: `localhost`)
- `SQLSERVER_PORT` (default: `1433`)
- `SQLSERVER_USERNAME` (default: `sa`)
- `SQLSERVER_PASSWORD`
- `SQLSERVER_DATABASE` (default: `rokaki`)

### MySQL
- `MYSQL_HOST` (default: `127.0.0.1`)
- `MYSQL_PORT` (default: `3306`)
- `MYSQL_USERNAME` (default: `rokaki`)
- `MYSQL_PASSWORD` (default: `rokaki`)
- `MYSQL_DATABASE` (default: `rokaki`)

### PostgreSQL
- `POSTGRES_HOST` (default: `127.0.0.1`)
- `POSTGRES_PORT` (default: `5432`)
- `POSTGRES_USERNAME` (default: `postgres`)
- `POSTGRES_PASSWORD` (default: `postgres`)
- `POSTGRES_DATABASE` (default: `rokaki`)

### Oracle
- `ORACLE_HOST` (default: `127.0.0.1`)
- `ORACLE_PORT` (default: `1521`)
- `ORACLE_USERNAME` (default: `ROKAKI`)
- `ORACLE_PASSWORD` (default: `rokaki`)
- `ORACLE_DATABASE` (service/alias; default: `/freepdb1` in CI)
- `ORACLE_SERVICE_NAME` (optional; if set, Rokaki builds a full descriptor string)

### SQLite
- `SQLITE_DATABASE` (path to a SQLite file; if unset, tests use an in-memory DB via `":memory:"`)

## Backend auto-detection

By default, Rokaki infers the database adapter from your model’s ActiveRecord connection.

- Single-adapter apps: no `db:` needed.
- Multiple adapters present: pass `db:` to `filter_model` (or call `filter_db`) to choose explicitly.
- Errors:
  - `Rokaki::Error: Multiple database adapters detected (...). Please declare which backend to use via db: or filter_db.`
  - `Rokaki::Error: Unable to auto-detect database adapter. Ensure your model is connected or pass db: explicitly.`

## SQL Server notes

- Rokaki uses `LIKE` with proper escaping and OR expansion for arrays of terms.
- Case sensitivity follows your database/column collation. Future versions may allow inline `COLLATE` options.

## Running tests locally

Ensure you have Ruby (see `.ruby-version`), then install dependencies and run specs.

```bash
bundle install
./spec/ordered_run.sh
```

Or run a single adapter suite, for example SQL Server:

```bash
bundle exec rspec spec/lib/03_sqlserver_aware_spec.rb
```

If your SQL Server listens on a different port (e.g., 1434), set an override:

```bash
export SQLSERVER_PORT=1434
bundle exec rspec spec/lib/03_sqlserver_aware_spec.rb
```

## GitHub Actions

The repository includes CI that starts MySQL (9.4), PostgreSQL (13), SQL Server (2022), and Oracle (23 Free) services and runs the ordered spec suite. SQLite is embedded and requires no service container. See `.github/workflows/spec.yml`.
