local enum
enum = require("lapis.db.model").enum
local Model
Model = require("community.model").Model
local to_json
to_json = require("lapis.util").to_json
local ActivityLogs
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
    action_name = function(self)
      return self.__class.actions[self.__class.object_types:to_name(self.object_type)][self.action]
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "ActivityLogs",
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
    }),
    pending_post = enum({
      create_post = 1,
      create_topic = 2,
      delete = 3,
      promote = 4
    })
  }
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
          "post",
          "Posts"
        },
        [3] = {
          "category",
          "Categories"
        },
        [4] = {
          "pending_post",
          "PendingPosts"
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
    if opts.object then
      local object = assert(opts.object, "missing object")
      opts.object = nil
      opts.object_id = assert(object.id, "object does not have id")
      opts.object_type = self:object_type_for_object(object)
    end
    opts.object_type = self.object_types:for_db(opts.object_type)
    local type_name = self.object_types:to_name(opts.object_type)
    local actions = self.actions[type_name]
    if not (actions) then
      error("missing action for type: " .. tostring(type_name))
    end
    opts.action = actions:for_db(opts.action)
    if opts.data then
      local db_json
      db_json = require("community.helpers.models").db_json
      opts.data = db_json(opts.data)
    end
    if not (opts.ip) then
      local CommunityUsers
      CommunityUsers = require("community.models").CommunityUsers
      opts.ip = CommunityUsers:current_ip_address()
    end
    return _class_0.__parent.create(self, opts)
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  ActivityLogs = _class_0
  return _class_0
end
