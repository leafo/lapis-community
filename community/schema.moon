
run_migrations = (version) ->
  m = require "lapis.db.migrations"

  migrations = require("community.migrations")

  if version and not migrations[tonumber version]
    versions = [key for key in pairs migrations]
    table.sort versions
    available_version = versions[#versions]
    error "Expected to migrate to lapis-community version #{version} but it was not found (have #{available_version}). Did you forget to update lapis-community?"

  m.run_migrations migrations, "community"

{ :run_migrations }
