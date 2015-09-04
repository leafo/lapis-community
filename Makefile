
.PHONY: clean_test test local count build

clean_test:
	-dropdb -U postgres community_test
	createdb -U postgres community_test
	LAPIS_SHOW_QUERIES=1 LAPIS_ENVIRONMENT=test lua5.1 -e 'require("schema").make_schema()'

clean_dev:
	-dropdb -U postgres community
	createdb -U postgres community
	LAPIS_SHOW_QUERIES=1 LAPIS_ENVIRONMENT=development lua5.1 -e 'require("schema").make_schema()'
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
	luarocks make --local lapis-community-dev-1.rockspec

