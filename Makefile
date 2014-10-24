
.PHONY: clean_test

clean_test: 
	-dropdb -U postgres community_test
	createdb -U postgres community_test
	lapis exec 'require("community.schema").make_schema()' test


