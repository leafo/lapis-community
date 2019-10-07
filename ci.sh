#!/bin/bash

set -e
set -o pipefail
set -o xtrace


luarocks --lua-version=5.1 install busted
luarocks --lua-version=5.1 install https://raw.githubusercontent.com/leafo/lapis/master/lapis-dev-1.rockspec
luarocks --lua-version=5.1 install moonscript
luarocks --lua-version=5.1 install date

luarocks --lua-version=5.1 make

# start postgres
echo "fsync = off" >> /var/lib/postgres/data/postgresql.conf
echo "synchronous_commit = off" >> /var/lib/postgres/data/postgresql.conf
echo "full_page_writes = off" >> /var/lib/postgres/data/postgresql.conf
su postgres -c '/usr/bin/pg_ctl -s -D /var/lib/postgres/data start -w -t 120'

echo "return 'test'" > lapis_environment.lua

moonc schema.moon
moonc config.moon
moonc community
createdb -U postgres community_test
LAPIS_SHOW_QUERIES=1 luajit -e 'require("schema").make_schema()'

cat $(which busted) | sed 's/\/usr\/bin\/lua5\.1/\/usr\/bin\/luajit/' > busted
chmod +x busted
./busted -o utfTerminal
