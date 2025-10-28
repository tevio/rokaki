---
layout: page
title: Database adapters
permalink: /adapters
---

Rokaki generates adapter‑aware SQL for PostgreSQL, MySQL, SQL Server, Oracle, and SQLite.

## Overview

- PostgreSQL
  - Case‑insensitive: `ILIKE`
  - Case‑sensitive: `LIKE`
  - Multi‑term: `ANY (ARRAY[...])`
- MySQL
  - Case‑insensitive: `LIKE`
  - Case‑sensitive: `LIKE BINARY`
  - Nested‑like filters may use `REGEXP` where designed in the library
- SQL Server
  - Uses `LIKE` with safe escaping
  - Multi‑term input expands to OR‑chained predicates (e.g., `(col LIKE :q0 OR col LIKE :q1 ...)`) with `ESCAPE '\\'`
  - Case sensitivity follows DB collation by default; future versions may add inline `COLLATE` options
- Oracle
  - Uses `LIKE`; arrays of terms are OR‑chained; case‑insensitive paths use `UPPER(column) LIKE UPPER(:q)`
  - See the dedicated page: [Oracle connections](/adapters/oracle) for connection strings, NLS settings, and common errors.
- SQLite
  - Embedded (no separate server needed)
  - Uses `LIKE`; arrays of terms are OR‑chained across predicates
  - Case sensitivity follows SQLite defaults (generally case‑sensitive for ASCII)

## LIKE modes

All adapters support the same modes, which you declare via the values in your `like` mapping (there is no `modes:` option):

- `prefix` → `%term`
- `suffix` → `term%`
- `circumfix` → `%term%` (synonyms supported: `:parafix`, `:confix`, `:ambifix`)

Example:

```ruby
# Declare modes via like-mapping values (no block DSL)
like title: :circumfix
like author: { first_name: :prefix }
```

When you pass an array of terms, Rokaki composes adapter‑appropriate SQL that matches any of the terms.

## Notes on case sensitivity

- PostgreSQL: `ILIKE` is case‑insensitive; `LIKE` is case‑sensitive depending on collation/LC settings but generally treated as case‑sensitive for ASCII.
- MySQL: `LIKE` case sensitivity depends on column collation; `LIKE BINARY` forces byte comparison (case‑sensitive for ASCII).
- SQL Server: The server/database/column collation determines sensitivity. Rokaki currently defers to your DB’s default. If you need deterministic behavior regardless of DB defaults, consider using a case‑sensitive collation on the column or open an issue to discuss inline `COLLATE` options.


## Backend auto-detection

Rokaki auto-detects the adapter from your model’s ActiveRecord connection in typical single-adapter apps. If multiple adapters are detected in the process and you do not specify one, Rokaki raises a helpful error asking you to choose.

- Default: no `db:` needed; the adapter is inferred from the model connection.
- Multiple adapters present: pass `db:` to `filter_model` (or call `filter_db`) to select one explicitly.
- Errors you may see:
  - `Rokaki::Error: Multiple database adapters detected (...). Please declare which backend to use via db: or filter_db.`
  - `Rokaki::Error: Unable to auto-detect database adapter. Ensure your model is connected or pass db: explicitly.`

## SQLite

SQLite is embedded and requires no separate server process. Rokaki treats it as a first-class adapter.

- Default test configuration uses an in-memory database.
- Arrays of terms in LIKE filters are OR-chained across predicates.
- Case sensitivity follows SQLite defaults (generally case-sensitive for ASCII); collations can affect this.

Example config (tests):

```yaml
adapter: sqlite3
database: ":memory:"
```

To persist a database file locally, set `SQLITE_DATABASE` to a path (e.g., `tmp/test.sqlite3`).


## Range/BETWEEN filters

Rokaki’s range filters (`between`, lower-bound aliases like `from`/`min`, and upper-bound aliases like `to`/`max`) are adapter‑agnostic. The library always generates parameterized predicates using `BETWEEN`, `>=`, and `<=` on the target column.

Adapter notes:
- PostgreSQL: Uses regular `WHERE column BETWEEN $1 AND $2` (or `>=`/`<=`). No special handling is required.
- MySQL/MariaDB: Uses `BETWEEN ? AND ?` (or `>=`/`<=`). Datetime values are compared with the column precision configured by your schema.
- SQLite: Uses `BETWEEN ? AND ?` (or `>=`/`<=`).
- SQL Server: Uses `BETWEEN @from AND @to` (or `>=`/`<=`). Parameters are bound via ActiveRecord.
- Oracle: Uses `BETWEEN :from AND :to` (or `>=`/`<=`). If your column type is `DATE`, be aware it has second precision; `TIMESTAMP` supports fractional seconds.

Tips:
- For date-only upper bounds (e.g., `2024-12-31`), Rokaki treats them inclusively and, when applicable, will extend to the end of day in basic filters to match expectations. If you need precise control, pass explicit `Time` values.
- Arrays are treated as equality lists (`IN (?)`) across all adapters. Use a `Range` or `{ between: [from, to] }` for range filtering.
- `nil` bounds are ignored: only the provided side is applied.
