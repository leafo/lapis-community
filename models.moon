import autoload from require "lapis.util"
loader = autoload "models" -- , "community.models"

setmetatable {}, __index: (name) =>
  assert loader[name], "failed to find model: #{name}"

