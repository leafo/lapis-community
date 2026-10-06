local db = require("lapis.db")
local Flow
Flow = require("lapis.flow").Flow
local PendingPosts, ActivityLogs, ModerationLogs
do
  local _obj_0 = require("community.models")
  PendingPosts, ActivityLogs, ModerationLogs = _obj_0.PendingPosts, _obj_0.ActivityLogs, _obj_0.ModerationLogs
end
do
  local _class_0
  local _parent_0 = Flow
  local _base_0 = {
    delete_pending_post = function(self, pending_post)
      if pending_post:delete() then
        ActivityLogs:create({
          user_id = self.current_user.id,
          object = pending_post,
          action = "delete"
        })
        return true
      end
    end,
    create_moderation_log = function(self, pending_post, opts)
      local topic = opts.topic or pending_post:get_topic()
      local category_id = pending_post.category_id or topic and topic.category_id
      local log_objects = {
        pending_post:get_user()
      }
      if topic then
        table.insert(log_objects, topic)
      end
      return ModerationLogs:create({
        user_id = self.current_user.id,
        object = opts.object,
        action = opts.action,
        category_id = category_id,
        log_objects = log_objects,
        data = {
          pending_post_id = pending_post.id,
          title = pending_post.title
        }
      })
    end,
    promote_pending_post = function(self, pending_post)
      local post, err = pending_post:promote(self)
      if not (post) then
        return nil, err
      end
      ActivityLogs:create({
        user_id = self.current_user.id,
        object = pending_post,
        action = "promote",
        data = {
          post_id = post.id
        }
      })
      self:create_moderation_log(pending_post, {
        object = post,
        topic = post:get_topic(),
        action = "post.approve_pending"
      })
      return post
    end,
    set_pending_post_status = function(self, pending_post, status)
      local statuses = pending_post.__class.statuses
      status = statuses:for_db(status)
      if pending_post.status == status then
        return true
      end
      if not (pending_post:update({
        status = status
      })) then
        return nil, "failed to update status"
      end
      self:create_moderation_log(pending_post, {
        object = pending_post,
        action = "pending_post.status(" .. tostring(statuses:to_name(status)) .. ")"
      })
      return true
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
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  PendingPosts = _class_0
  return _class_0
end
