local enum
enum = require("lapis.db.model").enum
local Model
Model = require("community.model").Model
local ModerationLogs
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
    set_log_objects = function(self, objects)
      local ModerationLogObjects
      ModerationLogObjects = require("community.models").ModerationLogObjects
      for _index_0 = 1, #objects do
        local o = objects[_index_0]
        ModerationLogObjects:create({
          moderation_log_id = self.id,
          object_type = ModerationLogObjects:object_type_for_object(o),
          object_id = o.id
        })
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "ModerationLogs",
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
    },
    {
      "category",
      belongs_to = "Categories"
    },
    {
      "log_objects",
      has_many = "ModerationLogObjects"
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
        },
        [3] = {
          "post_report",
          "PostReports"
        },
        [4] = {
          "category_group",
          "CategoryGroups"
        }
      }
    }
  }
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    assert(opts.user_id, "missing user_id")
    assert(opts.action, "missing action")
    local object = assert(opts.object, "missing object")
    opts.object = nil
    opts.object_id = object.id
    opts.object_type = self:object_type_for_object(object)
    local log_objects = opts.log_objects
    opts.log_objects = nil
    do
      local l = Model.create(self, opts)
      if log_objects then
        l:set_log_objects(log_objects)
      end
      return l
    end
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  ModerationLogs = _class_0
  return _class_0
end
