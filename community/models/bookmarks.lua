local db = require("lapis.db")
local Model
Model = require("community.model").Model
local insert_on_conflict_ignore
insert_on_conflict_ignore = require("community.helpers.models").insert_on_conflict_ignore
local Bookmarks
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
    __name = "Bookmarks",
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
    "user_id",
    "object_type",
    "object_id"
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
          "user",
          "Users"
        },
        [2] = {
          "topic",
          "Topics"
        },
        [3] = {
          "post",
          "Posts"
        }
      }
    }
  }
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    opts.object_type = self.object_types:for_db(opts.object_type)
    return insert_on_conflict_ignore(self, opts)
  end
  self.get = function(self, object, user)
    if not (user) then
      return nil
    end
    return self:find({
      user_id = user.id,
      object_id = object.id,
      object_type = self:object_type_for_model(object.__class)
    })
  end
  self.save = function(self, object, user)
    if not (user) then
      return 
    end
    return self:create({
      user_id = user.id,
      object_id = object.id,
      object_type = self:object_type_for_model(object.__class)
    })
  end
  self.remove = function(self, object, user)
    do
      local bookmark = self:get(object, user)
      if bookmark then
        return bookmark:delete()
      end
    end
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Bookmarks = _class_0
  return _class_0
end
