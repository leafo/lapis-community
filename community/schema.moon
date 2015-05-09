
run_migrations = ->
  m = require "lapis.db.migrations"
  m.run_migrations require("community.migrations"), "community"

{ :run_migrations }
