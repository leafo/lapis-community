local db = require("lapis.db")
local Model
Model = require("lapis.db.model").Model
local underscore, singularize
do
  local _obj_0 = require("lapis.util")
  underscore, singularize = _obj_0.underscore, _obj_0.singularize
end
local prefix = "community_"
local external_models = {
  Users = true
}
local CommunityModel
do
  local _parent_0 = Model
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  local _class_0 = setmetatable({
    __init = function(self, ...)
      return _parent_0.__init(self, ...)
    end,
    __base = _base_0,
    __name = "CommunityModel",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        return _parent_0[name]
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.get_relation_model = function(self, name)
    if external_models[name] then
      return require("models")[name]
    else
      return require("community.models")[name]
    end
  end
  self.table_name = function(self)
    local name = prefix .. underscore(self.__name)
    self.table_name = function()
      return name
    end
    return name
  end
  self.singular_name = function(self)
    local name = singularize(underscore(self.__name))
    self.singular_name = function()
      return name
    end
    return name
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  CommunityModel = _class_0
end
local prefix_table
prefix_table = function(table_name)
  return prefix .. table_name
end
return {
  Model = CommunityModel,
  prefix_table = prefix_table
}
