local enum
enum = require("lapis.db.model").enum
local Model
Model = require("community.model").Model
local safe_insert
safe_insert = require("community.helpers.models").safe_insert
local Bans
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
    __name = "Bans",
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
    "object_type",
    "object_id",
    "banned_user_id"
  }
  self.relations = {
    {
      "banned_user",
      belongs_to = "Users"
    },
    {
      "banning_user",
      belongs_to = "Users"
    },
    {
      "object",
      polymorphic_belongs_to = {
        [1] = {
          "category",
          "Categories"
        },
        [2] = {
          "topic",
          "Topics"
        },
        [3] = {
          "category_group",
          "CategoryGroups"
        }
      }
    }
  }
  self.find_for_object = function(self, object, user)
    if not (user) then
      return nil
    end
    return Bans:find({
      object_type = self:object_type_for_object(object),
      object_id = object.id,
      banned_user_id = user.id
    })
  end
  self.create = function(self, opts)
    assert(opts.object, "missing object")
    opts.object_id = opts.object.id
    opts.object_type = self:object_type_for_object(opts.object)
    opts.object = nil
    return safe_insert(self, opts)
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Bans = _class_0
  return _class_0
end
