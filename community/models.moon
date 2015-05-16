import autoload, underscore from require "lapis.util"

community_models = autoload "community.models"

loadkit = require "loadkit"

-- this will first load a model from community/models/X.lua
-- it will then check to see if there's a overriden version in the models/community/X.lua
-- if there is an overriden file, it's pass the reference to the origial model

setmetatable {}, __index: (model_name) =>
  base_model = community_models[model_name]

  unless base_model
    error "Failed to find community model: #{model_name}"

  override_module = "models.community.#{underscore model_name}"

  fname = loadkit.make_loader("lua") override_module
  custom_model = if fname
    assert(loadfile(fname)) base_model

  @[model_name] = custom_model or base_model
  @[model_name]

