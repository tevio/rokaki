#!/bin/bash
set -e

FILES="spec/lib/00_sqlite_aware_spec.rb spec/lib/01_postgres_aware_spec.rb spec/lib/02_mysql_aware_spec.rb spec/lib/03_sqlserver_aware_spec.rb spec/lib/04_oracle_aware_spec.rb"

for f in $FILES; do
  bundle exec rspec "$f"
done
