local autoload, underscore
do
  local _obj_0 = require("lapis.util")
  autoload, underscore = _obj_0.autoload, _obj_0.underscore
end
local community_models = autoload("community.models")
local loadkit = require("loadkit")
return setmetatable({ }, {
  __index = function(self, model_name)
    local base_model = community_models[model_name]
    if not (base_model) then
      error("Failed to find community model: " .. tostring(model_name))
    end
    local override_module = "models.community." .. tostring(underscore(model_name))
    local fname = loadkit.make_loader("lua")(override_module)
    local custom_model
    if fname then
      custom_model = assert(loadfile(fname))(base_model)
    end
    self[model_name] = custom_model or base_model
    return self[model_name]
  end
})
