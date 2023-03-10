local db = require("lapis.db")
local Model
Model = require("community.model").Model
local enum
enum = require("lapis.db.model").enum
local db_json
db_json = require("community.helpers.models").db_json
local PendingPosts
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
    allowed_to_moderate = function(self, user)
      do
        local parent = self:get_topic() or self:get_category()
        if parent then
          if parent:allowed_to_moderate(user) then
            return true
          end
        end
      end
      return false
    end,
    is_topic = function(self)
      return not self.topic_id
    end,
    promote = function(self, req_or_flow)
      if req_or_flow == nil then
        req_or_flow = nil
      end
      local Posts, Topics, CommunityUsers
      do
        local _obj_0 = require("community.models")
        Posts, Topics, CommunityUsers = _obj_0.Posts, _obj_0.Topics, _obj_0.CommunityUsers
      end
      local created_topic = false
      local topic
      if self:is_topic() then
        local category = self:get_category()
        if not (category) then
          return nil, "could not create topic for pending post due to lack of category"
        end
        created_topic = true
        topic = Topics:create({
          user_id = self.user_id,
          category_id = self.category_id,
          category_order = category:next_topic_category_order(),
          title = assert(self.title, "missing title for pending topic"),
          tags = (function()
            if self.data and self.data.topic_tags then
              return db.array(self.data.topic_tags)
            end
          end)()
        })
      else
        topic = self:get_topic()
      end
      if not (topic) then
        return nil, "failed to get or create topic to place pending post"
      end
      local post = Posts:create({
        topic_id = topic.id,
        user_id = self.user_id,
        parent_post = self:get_parent_post(),
        body = self.body,
        body_format = self.body_format,
        created_at = self.created_at
      }, {
        returning = "*"
      })
      topic:increment_from_post(post, {
        category_order = false
      })
      local cu = CommunityUsers:for_user(self:get_user())
      cu:increment_from_post(post, created_topic)
      if created_topic then
        self:get_category():increment_from_topic(topic)
      end
      post:on_body_updated_callback(req_or_flow)
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
    },
    {
      "activity_log_create",
      has_one = "ActivityLogs",
      key = "object_id",
      where = {
        object_type = 4,
        action = db.list({
          1,
          2
        })
      }
    }
  }
  self.statuses = enum({
    pending = 1,
    deleted = 2,
    spam = 3,
    ignored = 4
  })
  self.reasons = enum({
    manual = 1,
    risky = 2,
    warning = 3
  })
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    opts.status = self.statuses:for_db(opts.status or "pending")
    opts.reason = self.reasons:for_db(opts.reason or "manual")
    local Posts
    Posts = require("community.models").Posts
    opts.body_format = Posts.body_formats:for_db(opts.body_format or 1)
    if opts.data then
      opts.data = db_json(opts.data)
    end
    return _class_0.__parent.create(self, opts)
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  PendingPosts = _class_0
  return _class_0
end
