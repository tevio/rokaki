---
layout: page
title: Database adapters
permalink: /adapters
---

Rokaki generates adapter‑aware SQL for PostgreSQL, MySQL, and SQL Server.

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

## LIKE modes

All adapters support the same modes:

- `prefix` → `%term`
- `suffix` → `term%`
- `circumfix` → `%term%`

When you pass an array of terms, Rokaki composes adapter‑appropriate SQL that matches any of the terms.

## Notes on case sensitivity

- PostgreSQL: `ILIKE` is case‑insensitive; `LIKE` is case‑sensitive depending on collation/LC settings but generally treated as case‑sensitive for ASCII.
- MySQL: `LIKE` case sensitivity depends on column collation; `LIKE BINARY` forces byte comparison (case‑sensitive for ASCII).
- SQL Server: The server/database/column collation determines sensitivity. Rokaki currently defers to your DB’s default. If you need deterministic behavior regardless of DB defaults, consider using a case‑sensitive collation on the column or open an issue to discuss inline `COLLATE` options.
