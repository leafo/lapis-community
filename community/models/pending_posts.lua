local db = require("lapis.db")
local Model
Model = require("community.model").Model
local enum
enum = require("lapis.db.model").enum
local PendingPosts
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
    allowed_to_moderate = function(self, user)
      local topic = self:get_topic()
      return topic:allowed_to_moderate(user)
    end,
    promote = function(self)
      local Posts, CommunityUsers
      do
        local _obj_0 = require("community.models")
        Posts, CommunityUsers = _obj_0.Posts, _obj_0.CommunityUsers
      end
      local post = Posts:create({
        topic_id = self.topic_id,
        user_id = self.user_id,
        parent_post = self.parent_post,
        body = self.body,
        created_at = self.created_at
      })
      local topic = self:get_topic()
      topic:increment_from_post(post)
      do
        local category = topic:get_category()
        if category then
          category:increment_from_post(post)
        end
      end
      CommunityUsers:for_user(self:get_user()):increment("posts_count")
      topic:increment_participant(self:get_user())
      self:delete()
      return post
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "PendingPosts",
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
      "topic",
      belongs_to = "Topics"
    },
    {
      "user",
      belongs_to = "Users"
    },
    {
      "parent_post",
      belongs_to = "Posts"
    },
    {
      "category",
      belongs_to = "Categories"
    }
  }
  self.statuses = enum({
    pending = 1,
    deleted = 2,
    spam = 3
  })
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    opts.status = self.statuses:for_db(opts.status or "pending")
    return Model.create(self, opts)
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  PendingPosts = _class_0
  return _class_0
end
