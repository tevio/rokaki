#!/bin/bash
set -e

for f in spec/lib/01_postgres_aware_spec.rb spec/lib/02_mysql_aware_spec.rb
do
  bundle exec rspec $f
done
