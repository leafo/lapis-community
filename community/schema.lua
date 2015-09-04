local run_migrations
run_migrations = function()
  local m = require("lapis.db.migrations")
  return m.run_migrations(require("community.migrations"), "community")
end
return {
  run_migrations = run_migrations
}
