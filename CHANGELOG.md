### Unreleased
- Documentation: Added comprehensive Range/BETWEEN/MIN/MAX filter docs across README and site (usage, adapters). Clarified sub-key aliases (`between`, `from`/`since`/`after`/`start`/`min`, `to`/`until`/`before`/`end`/`max`), accepted value shapes (Range, 2‑element Array, Hash), nested examples, and equality array semantics (`IN` vs `BETWEEN`).
- Documentation: Added backend auto‑detection feature docs across README and site (index, usage, adapters, configuration). Examples now prefer auto‑detection by default and explain explicit overrides and ambiguity errors.
- Tests: Added shared examples to exercise auto‑detection behavior under each adapter suite.

### 0.15.0 — 2025-10-27
- Add first-class SQLite support: adapter-aware LIKE behavior with OR expansion for arrays.
- Added SQLite badge in README.
- Updated documentation: adapters, configuration, index and usage; noted SQLite default in-memory config and env override `SQLITE_DATABASE`.
- Internal: introduced `generic_like` helper for generic adapters (used by SQLite); no breaking changes for other adapters.

### 0.13.0 — 2025-10-25
- Add block-form DSL parity across both FilterModel and Filterable (`filter_map do ... end` with `like`, `ilike`, `nested`, and `filters`).
- Support circumfix affix synonyms: `:parafix`, `:confix`, `:ambifix` (treated as `:circumfix`).
- Improve docs with block-form examples and adapter behavior notes.
- Keep SQL Server support (introduced earlier) covered in CI; add shared tests for affix synonyms to all adapter-aware specs.
- Allow ENV overrides for all adapters in test DatabaseManager (Postgres/MySQL/SQL Server).

### 0.12.0 — 2025-10-25
- Introduce block-form DSL for FilterModel (`filter_map do ... end`) with `like` and `nested`.
- Update docs site and GitHub Pages build.

### 0.11.0 — 2025-10-25
- Add first-class SQL Server support.
- CI updates to run tests against SQL Server, alongside PostgreSQL and MySQL.

### 0.10.0 and earlier
- Core DSL: Filterable and FilterModel modes, LIKE matching with prefix/suffix/circumfix, nested filters, and adapter-aware SQL for Postgres/MySQL.

### 0.14.1 — 2025-10-25
- Oracle enabled by default in tests and CI; added Oracle service and Instant Client install in GitHub Actions (Ubuntu 24.04: use libaio1t64, Instant Client ZIP install).
- Removed `ORACLE_ENABLED` flag from runner; Oracle suite runs in `./spec/ordered_run.sh` by default.
- ActiveRecord 8 support: relaxed dev dependency to `>= 7.1, < 9.0`.
- Added dynamic runtime listener tests (anonymous classes) across all adapters and documentation section.
- Simplified README with concise overview and links to GitHub Pages; moved legacy content to `README.legacy.md`.
