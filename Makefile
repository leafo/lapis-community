
.PHONY: clean_test test

clean_test:
	-dropdb -U postgres community_test
	createdb -U postgres community_test
	lapis exec 'require("schema").make_schema()' test
	lapis exec 'require("community.schema").make_schema()' test

test:
	busted

lint:
	moonc -l community/
	moonc -l spec/
