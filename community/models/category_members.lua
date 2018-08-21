local db = require("lapis.db")
local Model
Model = require("community.model").Model
local CategoryMembers
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
    __name = "CategoryMembers",
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
  self.primary_key = {
    "user_id",
    "category_id"
  }
  self.relations = {
    {
      "user",
      belongs_to = "Users"
    },
    {
      "category",
      belongs_to = "Categories"
    }
  }
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    assert(opts.user_id, "missing user id")
    assert(opts.category_id, "missing category id")
    local insert_on_conflict_ignore
    insert_on_conflict_ignore = require("community.helpers.models").insert_on_conflict_ignore
    return insert_on_conflict_ignore(self, opts)
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  CategoryMembers = _class_0
  return _class_0
end
