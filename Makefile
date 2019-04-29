
.PHONY: clean_test test local count build seed schema.sql

clean_test: build
	-dropdb -U postgres community_test
	createdb -U postgres community_test
	LAPIS_SHOW_QUERIES=1 LAPIS_ENVIRONMENT=test lua5.1 -e 'require("schema").make_schema()'
	make schema.sql

clean_dev:
	-dropdb -U postgres community
	createdb -U postgres community
	LAPIS_SHOW_QUERIES=1 LAPIS_ENVIRONMENT=development lua5.1 -e 'require("schema").make_schema()'

seed:
	LAPIS_SHOW_QUERIES=1 moon cmd/seed.moon

test:
	busted

lint:
	moonc -l community/
	moonc -l spec/
	# moonc -l views/
	moonc -l app.moon

count:
	wc -l $$(git ls-files | grep 'scss$$\|moon$$\|coffee$$\|md$$\|conf$$') | sort -n | tail

build:
	moonc community
	tup upd

local: build
	luarocks --lua-version=5.1 make --local lapis-community-dev-1.rockspec

annotate_models: clean_dev
	lapis annotate $$(find community/models -type f | grep moon$$)

# update the schema.sql from schema in dev db
schema.sql:
	pg_dump -s -U postgres community_test > schema.sql
	pg_dump -a -t lapis_migrations -U postgres community_test >> schema.sql
