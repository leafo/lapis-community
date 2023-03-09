local db = require("lapis.db")
local enum
enum = require("lapis.db.model").enum
local Model
Model = require("community.model").Model
local Warnings
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
    is_active = function(self)
      local date = require("date")
      return not self.expires_at or date(self.expires_at) < dfate(true)
    end,
    mark_active = function(self)
      return self:update({
        first_seen_at = db.raw("now() at time zone 'UTC'"),
        expires_at = db.raw("now() at time zone 'UTC' + interval")
      }, {
        where = db.clause({
          first_seen_at = db.NULL
        })
      })
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "Warnings",
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
  self.timestamp = true
  self.relations = {
    {
      "user",
      belongs_to = "Users"
    }
  }
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Warnings = _class_0
  return _class_0
end
