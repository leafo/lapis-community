local enum
enum = require("lapis.db.model").enum
local Model
Model = require("community.model").Model
local to_json
to_json = require("lapis.util").to_json
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
    end,
    create_backing_post = function(self)
      if not (self.object_type == self.__class.object_types.topic) then
        return nil, "not a topic moderation"
      end
      local Posts
      Posts = require("community.models").Posts
      local post = Posts:create({
        moderation_log_id = self.id,
        body = "",
        topic_id = self.object_id,
        user_id = self.user_id
      })
      local topic = self:get_object()
      topic:increment_from_post(post)
      return post
    end,
    get_action_text = function(self)
      local _exp_0 = self.action
      if "topic.move" == _exp_0 then
        return "moved this topic to"
      elseif "topic.archive" == _exp_0 then
        return "archived this topic"
      elseif "topic.unarchive" == _exp_0 then
        return "unarchived this topic"
      elseif "topic.lock" == _exp_0 then
        return "locked this topic"
      elseif "topic.unlock" == _exp_0 then
        return "unlocked this topic"
      end
    end,
    get_action_target = function(self)
      return self:get_target_category()
    end,
    get_target_category = function(self)
      if not (self.action == "topic.move" and self.data and self.data.target_category_id) then
        return nil, "no target category"
      end
      if self.target_category == nil then
        local Categories
        Categories = require("community.models").Categories
        self.target_category = Categories:find(self.data.target_category_id)
        self.target_category = self.target_category or false
      end
      return self.target_category
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
  self.create_post_for = {
    ["topic.move"] = true,
    ["topic.archive"] = true,
    ["topic.unarchive"] = true,
    ["topic.lock"] = true,
    ["topic.unlock"] = true,
    ["topic.hide"] = true,
    ["topic.unhide"] = true
  }
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    assert(opts.user_id, "missing user_id")
    assert(opts.action, "missing action")
    if type(opts.data) == "table" then
      opts.data = to_json(opts.data)
    end
    local object = assert(opts.object, "missing object")
    opts.object = nil
    opts.object_id = object.id
    opts.object_type = self:object_type_for_object(object)
    local log_objects = opts.log_objects
    opts.log_objects = nil
    local create_backing_post = opts.backing_post ~= false
    opts.backing_post = nil
    do
      local l = _class_0.__parent.create(self, opts)
      if log_objects then
        l:set_log_objects(log_objects)
      end
      if create_backing_post and self.create_post_for[l.action] then
        l:create_backing_post()
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
