local db = require("lapis.db")
local Model
Model = require("community.model").Model
local safe_insert
safe_insert = require("community.helpers.models").safe_insert
local Subscriptions
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "Subscriptions",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
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
  self.primary_key = {
    "object_type",
    "object_id",
    "user_id"
  }
  self.timestamp = true
  self.relations = {
    {
      "user",
      belongs_to = "Users"
    },
    {
      "object",
      polymorphic_belongs_to = {
        [1] = {
          "topic",
          "Topics"
        },
        [2] = {
          "category",
          "Categories"
        }
      }
    }
  }
  self.create = safe_insert
  self.subscribe = function(self, object, user, subscribed_by_default)
    if subscribed_by_default == nil then
      subscribed_by_default = false
    end
  end
  self.unsubscribe = function(self, object, user, subscribed_by_default)
    if subscribed_by_default == nil then
      subscribed_by_default = false
    end
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Subscriptions = _class_0
  return _class_0
end
