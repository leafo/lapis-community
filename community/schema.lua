local run_migrations
run_migrations = function(version)
  local m = require("lapis.db.migrations")
  if version then
    assert(m[tonumber(version)], "Expected to migrate to lapis-community version " .. tostring(version) .. " but it was not found. Did you forget to update lapis-community?")
  end
  return m.run_migrations(require("community.migrations"), "community")
end
return {
  run_migrations = run_migrations
}
