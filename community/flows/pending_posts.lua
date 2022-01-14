local db = require("lapis.db")
local Flow
Flow = require("lapis.flow").Flow
local PendingPosts, ActivityLogs
do
  local _obj_0 = require("community.models")
  PendingPosts, ActivityLogs = _obj_0.PendingPosts, _obj_0.ActivityLogs
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
    promote_pending_post = function(self, pending_post)
      do
        local post = pending_post:promote()
        if post then
          ActivityLogs:create({
            user_id = self.current_user.id,
            object = pending_post,
            action = "promote",
            data = {
              post_id = post.id
            }
          })
          return true
        end
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
