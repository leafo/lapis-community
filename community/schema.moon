
run_migrations = (version) ->
  m = require "lapis.db.migrations"

  if version
    assert m[tonumber version], "Expected to migrate to lapis-community version #{version} but it was not found. Did you forget to update lapis-community?"

  m.run_migrations require("community.migrations"), "community"

{ :run_migrations }
