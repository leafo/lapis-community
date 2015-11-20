local db = require("lapis.db")
local Model
Model = require("community.model").Model
local TopicParticipants
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
    __name = "TopicParticipants",
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
    "topic_id",
    "user_id"
  }
  self.timestamp = true
  self.relations = {
    {
      "user",
      belongs_to = "Users"
    },
    {
      "topic",
      belongs_to = "Topics"
    }
  }
  self.increment = function(self, topic_id, user_id)
    local upsert
    upsert = require("community.helpers.models").upsert
    return upsert(self, {
      user_id = user_id,
      topic_id = topic_id,
      posts_count = 1
    }, {
      posts_count = db.raw("posts_count + 1")
    })
  end
  self.decrement = function(self, topic_id, user_id)
    local key = {
      user_id = user_id,
      topic_id = topic_id
    }
    local res = db.update(self:table_name(), {
      posts_count = db.raw("posts_count - 1")
    }, key, "posts_count")
    if res[1] and res[1].posts_count == 0 then
      key.posts_count = 0
      return db.delete(self:table_name(), key)
    end
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  TopicParticipants = _class_0
  return _class_0
end
