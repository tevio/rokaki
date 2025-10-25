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
