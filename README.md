# Rokaki

[![Gem Version](https://badge.fury.io/rb/rokaki.svg)](https://badge.fury.io/rb/rokaki)
[![Run RSpec tests](https://github.com/tevio/rokaki/actions/workflows/spec.yml/badge.svg)](https://github.com/tevio/rokaki/actions/workflows/spec.yml)

Supported backends:

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-336791?logo=postgresql&logoColor=white)](https://github.com/tevio/rokaki/actions/workflows/spec.yml)
[![MySQL](https://img.shields.io/badge/MySQL-4479A1?logo=mysql&logoColor=white)](https://github.com/tevio/rokaki/actions/workflows/spec.yml)
[![SQL Server](https://img.shields.io/badge/SQL%20Server-CC2927?logo=microsoft-sql-server&logoColor=white)](https://github.com/tevio/rokaki/actions/workflows/spec.yml)
[![Oracle](https://img.shields.io/badge/Oracle-F80000?logo=oracle&logoColor=white)](https://github.com/tevio/rokaki/actions/workflows/spec.yml)
[![SQLite](https://img.shields.io/badge/SQLite-003B57?logo=sqlite&logoColor=white)](https://github.com/tevio/rokaki/actions/workflows/spec.yml)

Rokaki is a small DSL for building safe, composable filters for ActiveRecord queries — without writing SQL. It maps incoming params to predicates on models and associations and works across PostgreSQL, MySQL, SQL Server, Oracle, and SQLite.

- Works with ActiveRecord 7.1 and 8.x
- LIKE modes: `:prefix`, `:suffix`, `:circumfix` (+ synonyms) and array‑of‑terms
- Nested filters with auto‑joins and qualified columns
- Auto‑detects the database backend; specify `db:` only when your app uses multiple adapters or you need an override
- Block‑form DSL (`filter_map do ... end`) and classic argument form
- Runtime usage: build an anonymous filter class from a payload (no predeclared class needed)

Install
```ruby
gem "rokaki"
```

Or from github

```ruby
gem 'rokaki', git: 'https://github.com/tevio/rokaki.git'
```

Docs
- Usage and examples: https://tevio.github.io/rokaki/usage
- Adapters: https://tevio.github.io/rokaki/adapters
- Configuration: https://tevio.github.io/rokaki/configuration

Tip: For a dynamic runtime listener (build a filter class from a JSON/hash payload at runtime), see “Dynamic runtime listener” in the Usage docs.

## Range filters (between/min/max)

Use the field name as the key and the filter type as a sub-key, or pass a `Range` directly. Aliases are supported.

```ruby
# Top-level
Article.filter(published: { from: Date.new(2024,1,1), to: Date.new(2024,12,31) })
Article.filter(published: (Date.new(2024,1,1)..Date.new(2024,12,31)))

# Nested
Article.filter(reviews_published: { max: Time.utc(2024,6,30) })
```

- Lower bound aliases (>=): `from`, `since`, `after`, `start`, `min`
- Upper bound aliases (<=): `to`, `until`, `before`, `end`, `max`
- Arrays always mean `IN (?)` for equality. Use a `Range` or `{ between: [from, to] }` for range filtering

See full docs: https://tevio.github.io/rokaki/usage#range-between-min-and-max-filters

---

## Further reading

[Legacy README](README.legacy.md)
