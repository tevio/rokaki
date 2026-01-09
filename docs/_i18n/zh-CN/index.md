---
layout: home
title: Rokaki
permalink: /
---

{% include lang_switcher.html %}

<!-- Translation draft (zh-CN): This localized page is initially populated with a brief English summary. Community review welcome. -->

Rokaki is a small Ruby library that helps you build safe, composable filters for ActiveRecord queries in web requests.

- Works with PostgreSQL, MySQL, SQL Server, Oracle, and SQLite
- LIKE-based matching (prefix/suffix/circumfix) and nested filters
- Auto-detects the database backend; specify db only when your app uses multiple adapters or you need an override

Get started:
- [Usage](./usage)
- [Database adapters](./adapters)
- [Configuration](./configuration)
