# Rokaki

[![Gem Version](https://badge.fury.io/rb/rokaki.svg)](https://badge.fury.io/rb/rokaki)
[![Run RSpec tests](https://github.com/tevio/rokaki/actions/workflows/spec.yml/badge.svg)](https://github.com/tevio/rokaki/actions/workflows/spec.yml)

Supported backends:

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-336791?logo=postgresql&logoColor=white)](https://github.com/tevio/rokaki/actions/workflows/spec.yml)
[![MySQL](https://img.shields.io/badge/MySQL-4479A1?logo=mysql&logoColor=white)](https://github.com/tevio/rokaki/actions/workflows/spec.yml)
[![SQL Server](https://img.shields.io/badge/SQL%20Server-CC2927?logo=microsoft-sql-server&logoColor=white)](https://github.com/tevio/rokaki/actions/workflows/spec.yml)
[![Oracle](https://img.shields.io/badge/Oracle-F80000?logo=oracle&logoColor=white)](https://github.com/tevio/rokaki/actions/workflows/spec.yml)

Rokaki is a small DSL for building safe, composable filters for ActiveRecord queries — without writing SQL. It maps incoming params to predicates on models and associations and works across PostgreSQL, MySQL, SQL Server, and Oracle.

- Works with ActiveRecord 7.1 and 8.x
- LIKE modes: `:prefix`, `:suffix`, `:circumfix` (+ synonyms) and array‑of‑terms
- Nested filters with auto‑joins and qualified columns
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

---

<<<<<<< HEAD
To use the DSL first include the `Rokaki::Filterable` module in your class.
=======
## Further reading
>>>>>>> c188dc7 (update documentation and dynamic testing)

[Legacy README](README.legacy.md)
