---
layout: page
title: Rokaki's DSL Syntax
permalink: /dsl-syntax
---

This page describes Rokaki’s domain-specific language (DSL) for declaring mappings and how incoming payloads are interpreted, with a focus on the difference between join-structure keys and leaf-level field keys.

The same concepts apply to both DSL entry points:
- FilterModel (querying a specific ActiveRecord model)
- Filterable (key mapping only)

See also: Usage, Adapters, and Configuration pages linked from the site index.

## Key ideas

- You declare the shape of your filterable graph in code. This defines which associations (joins) are traversed and which fields are addressable (leaves).
- At runtime, the payload mirrors only the declared structure. Values at leaves drive the operator semantics (equality, LIKE, range). The structure of joins does not change at runtime.

## Join-structure keys vs leaf-level field keys

- Join-structure keys represent associations. They appear only in the mapping you write (and mirrored by the payload). They do not carry operators by themselves. Examples: `author`, `reviews`, `articles`.
- Leaf-level field keys represent actual database columns on the current model or on a joined association. Examples: `title`, `content`, `published`, `first_name`.
- The mapping defines where a key is treated as a join (non-leaf) vs a field (leaf). At a declared leaf, the value can be a scalar, array, range, or an operator-hash (see below). Rokaki will not traverse deeper than the declared leaf.

## Declaring mappings

Two equivalent styles are supported:

### Argument-based form (classic)

```ruby
class ArticleQuery
  include Rokaki::FilterModel

  filter_model :article               # Adapter auto-detected; pass db: if needed
  define_query_key :q                 # Map a single query key to many fields

  like title: :circumfix, content: :circumfix # LIKE mappings (no modes: option)

  # Nested LIKEs and filters via association-shaped hashes
  like author: { first_name: :prefix, last_name: :suffix }

  # Declare equality/range-capable fields (leafs)
  filters :published                  # enables :published in payload
  filters reviews: :published         # enables nested reviews.published

  attr_accessor :filters
  def initialize(filters: {})
    @filters = filters
  end
end
```

### Block-form DSL

```ruby
class ArticleQuery
  include Rokaki::FilterModel

  filter_model :article
  define_query_key :q

  filter_map do
    like title: :circumfix, content: :circumfix

    nested :author do
      like first_name: :prefix, last_name: :suffix
      filters :id         # leaf field under author
    end

    nested :reviews do
      filters :published  # leaf field under reviews
    end
  end

  attr_accessor :filters
  def initialize(filters: {})
    @filters = filters
  end
end
```

## Payload rules (what values mean at a leaf)

At a leaf field (e.g., `published` or `reviews.published`):

- Scalar value → equality on the column
  - Example: `{ published: Time.utc(2024,1,1) }` → `WHERE published = :v`

- Array value → equality `IN` list
  - Arrays always mean `IN` across adapters.
  - Example: `{ published: [t1, t2, t3] }` → `WHERE published IN (?, ?, ?)`

- Range (`a..b`) → between
  - Example: `{ published: (t1..t2) }` → `WHERE published BETWEEN :from AND :to`

- Operator-hash (range-style keys) → between or open-ended bounds
  - Reserved keys at the leaf indicate operator semantics:
    - `between`
    - Lower-bound aliases (>=): `from`, `since`, `after`, `start`, `min`
    - Upper-bound aliases (<=): `to`, `until`, `before`, `end`, `max`
  - Examples:
    - `{ published: { from: t1, to: t2 } }`
    - `{ published: { between: [t1, t2] } }`
    - `{ published: { min: t1 } }` → `published >= t1`
    - `{ published: { max: t2 } }` → `published <= t2`

Notes:
- Only the leaf level interprets these reserved keys. Join-structure keys do not carry operators.
- Arrays never imply range; to express a range with an array, use `{ published: { between: [from, to] } }`.
- Nil bounds are ignored: `{ published: { from: t1 } }` applies only the lower bound.

## LIKE mappings and payloads

- You declare LIKE semantics in code via the `like` mapping; the payload provides the terms.
- Modes:
  - `:prefix` → `%term`
  - `:suffix` → `term%`
  - `:circumfix` (synonyms: `:parafix`, `:confix`, `:ambifix`) → `%term%`
- Payload values for LIKE can be a string or an array of strings. Arrays are matched with adapter-aware OR semantics.

Examples:
```ruby
like title: :circumfix
like author: { first_name: :prefix }

# Payload examples
{ q: "First" }
{ author: { first_name: ["Ada", "Al"] } }
```

## Nested examples

Top-level field range:
```ruby
ArticleQuery.new(filters: { published: { since: Time.utc(2024,1,1), until: Time.utc(2024,6,30) } }).results
```

Nested association field range:
```ruby
ArticleQuery.new(filters: { reviews: { published: (Time.utc(2024,1,1)..Time.utc(2024,6,30)) } }).results
```

Deep nested example (author → articles → reviews.published):
```ruby
class AuthorQuery
  include Rokaki::FilterModel
  filter_model :author
  filter_map do
    nested :articles do
      nested :reviews do
        filters :published
      end
    end
  end
  attr_accessor :filters
  def initialize(filters: {}) ; @filters = filters ; end
end

AuthorQuery.new(filters: { articles: { reviews: { published: { max: Time.utc(2024,6,30) } } } }).results
```

## Dynamic runtime listener

You can build a filter class at runtime from a payload (see Usage → Dynamic runtime listener). The same rules apply: the mapping fixes the join structure; leaf values drive operators.

```ruby
payload = {
  model: :article, db: :postgres, query_key: :q,
  like: { title: :circumfix, author: { first_name: :prefix } }
}
listener = Class.new do
  include Rokaki::FilterModel
  filter_model payload[:model], db: payload[:db]
  define_query_key payload[:query_key]
  filter_map { like payload[:like] }
  attr_accessor :filters
  def initialize(filters: {}) ; @filters = filters ; end
end

listener.new(filters: { q: "First" }).results
```

## Adapter behavior

- Range/bounds predicates (`BETWEEN`, `>=`, `<=`) are adapter-agnostic; Rokaki binds parameters appropriately for PostgreSQL, MySQL, SQL Server, Oracle, and SQLite.
- LIKE behavior is adapter-aware (e.g., Postgres `ANY(ARRAY[..])`, SQL Server `ESCAPE` clause, Oracle `UPPER()` for case-insensitive paths). See the Adapters page for details.

## Quick reference

- Join-structure keys: associations, declared in code, mirrored in payload structure; never carry operators.
- Leaf-level keys: columns/fields, declared in code with `filters`, accept values that determine semantics.
- Reserved leaf operator keys: `between`, `from`/`since`/`after`/`start`/`min`, `to`/`until`/`before`/`end`/`max`.
- Arrays: always equality `IN`.
- Ranges or operator-hash: range filtering.
