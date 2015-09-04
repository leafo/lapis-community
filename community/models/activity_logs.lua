local enum
enum = require("lapis.db.model").enum
local Model
Model = require("community.model").Model
local to_json
to_json = require("lapis.util").to_json
local ActivityLogs
do
  local _parent_0 = Model
  local _base_0 = {
    action_name = function(self)
      return self.__class.actions[self.__class.object_types:to_name(self.object_type)][self.action]
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  local _class_0 = setmetatable({
    __init = function(self, ...)
      return _parent_0.__init(self, ...)
    end,
    __base = _base_0,
    __name = "ActivityLogs",
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
  self.timestamp = true
  self.actions = {
    topic = enum({
      create = 1,
      delete = 2
    }),
    post = enum({
      create = 1,
      delete = 2,
      edit = 3,
      vote = 4
    }),
    category = enum({
      create = 1,
      edit = 2
    })
  }
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
      "object",
      polymorphic_belongs_to = {
        [1] = {
          "topic",
          "Topics"
        },
        [2] = {
          "post",
          "Posts"
        },
        [3] = {
          "category",
          "Categories"
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
    opts.object_id = assert(object.id, "object does not have id")
    opts.object_type = self:object_type_for_object(object)
    local type_name = self.object_types:to_name(opts.object_type)
    local actions = self.actions[type_name]
    if not (actions) then
      error("missing action for type: " .. tostring(type_name))
    end
    opts.action = actions:for_db(opts.action)
    if opts.data then
      opts.data = to_json(opts.data)
    end
    return Model.create(self, opts)
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  ActivityLogs = _class_0
  return _class_0
end
