local db = require("lapis.db")
local Flow
Flow = require("lapis.flow").Flow
local Topics, Posts, CommunityUsers, ActivityLogs
do
  local _obj_0 = require("community.models")
  Topics, Posts, CommunityUsers, ActivityLogs = _obj_0.Topics, _obj_0.Posts, _obj_0.CommunityUsers, _obj_0.ActivityLogs
end
local assert_error
assert_error = require("lapis.application").assert_error
local trim_filter
trim_filter = require("lapis.util").trim_filter
local assert_valid
assert_valid = require("lapis.validate").assert_valid
local require_login
require_login = require("community.helpers.app").require_login
local is_empty_html
is_empty_html = require("community.helpers.html").is_empty_html
local limits = require("community.limits")
local shapes = require("community.helpers.shapes")
local types
types = require("tableshape").types
local TopicsFlow
do
  local _class_0
  local _parent_0 = Flow
  local _base_0 = {
    expose_assigns = true,
    bans_flow = function(self)
      self:load_topic()
      local BansFlow = require("community.flows.bans")
      return BansFlow(self, self.topic)
    end,
    load_topic = function(self)
      if self.topic then
        return 
      end
      local params = shapes.assert_valid(self.params, {
        {
          "topic_id",
          shapes.db_id
        }
      })
      self.topic = Topics:find(params.topic_id)
      return assert_error(self.topic, "invalid topic")
    end,
    load_topic_for_moderation = function(self)
      self:load_topic()
      return assert_error(self.topic:allowed_to_moderate(self.current_user), "invalid user")
    end,
    write_moderation_log = function(self, action, reason, extra_params)
      self:load_topic()
      local ModerationLogs
      ModerationLogs = require("community.models").ModerationLogs
      local params = {
        user_id = self.current_user.id,
        object = self.topic,
        category_id = self.topic.category_id,
        action = action,
        reason = reason
      }
      if extra_params then
        for k, v in pairs(extra_params) do
          params[k] = v
        end
      end
      return ModerationLogs:create(params)
    end,
    new_topic = require_login(function(self)
      local CategoriesFlow = require("community.flows.categories")
      CategoriesFlow(self):load_category()
      assert_error(self.category:allowed_to_post_topic(self.current_user, self._req))
      local moderator = self.category:allowed_to_moderate(self.current_user)
      assert_valid(self.params, {
        {
          "topic",
          type = "table"
        }
      })
      local new_topic = shapes.assert_valid(self.params.topic, {
        {
          "title",
          shapes.limited_text(limits.MAX_TITLE_LEN)
        },
        {
          "body",
          shapes.limited_text(limits.MAX_BODY_LEN)
        },
        {
          "body_format",
          shapes.db_enum(Posts.body_formats) + shapes.empty / Posts.body_formats.html
        },
        {
          "tags",
          shapes.empty + shapes.limited_text(240) / (function()
            local _base_1 = self.category
            local _fn_0 = _base_1.parse_tags
            return function(...)
              return _fn_0(_base_1, ...)
            end
          end)()
        },
        {
          "sticky",
          shapes.empty / false + types.any / true
        },
        {
          "locked",
          shapes.empty / false + types.any / true
        }
      })
      local body = assert_error(Posts:filter_body(new_topic.body, new_topic.body_format))
      local sticky = false
      local locked = false
      if moderator then
        sticky = new_topic.sticky
        locked = new_topic.locked
      end
      self.topic = Topics:create({
        user_id = self.current_user.id,
        category_id = self.category.id,
        title = new_topic.title,
        tags = new_topic.tags and db.array((function()
          local _accum_0 = { }
          local _len_0 = 1
          local _list_0 = new_topic.tags
          for _index_0 = 1, #_list_0 do
            local t = _list_0[_index_0]
            _accum_0[_len_0] = t.slug
            _len_0 = _len_0 + 1
          end
          return _accum_0
        end)()),
        category_order = self.category:next_topic_category_order(),
        sticky = sticky,
        locked = locked
      })
      self.post = Posts:create({
        user_id = self.current_user.id,
        topic_id = self.topic.id,
        body_format = new_topic.body_format,
        body = body
      })
      self.topic:increment_from_post(self.post, {
        update_category_order = false
      })
      self.category:increment_from_topic(self.topic)
      CommunityUsers:for_user(self.current_user):increment("topics_count")
      self.topic:increment_participant(self.current_user)
      self.post:refresh_search_index()
      ActivityLogs:create({
        user_id = self.current_user.id,
        object = self.topic,
        action = "create"
      })
      return true
    end),
    delete_topic = require_login(function(self)
      self:load_topic()
      assert_error(self.topic:allowed_to_edit(self.current_user), "not allowed to edit")
      assert_error(not self.topic.permanent, "can't delete permanent topic")
      if self.topic:delete() then
        ActivityLogs:create({
          user_id = self.current_user.id,
          object = self.topic,
          action = "delete"
        })
        if self.topic:allowed_to_moderate(self.current_user) then
          self:write_moderation_log("topic.delete", self.params.reason)
        end
        return true
      end
    end),
    lock_topic = require_login(function(self)
      self:load_topic_for_moderation()
      trim_filter(self.params)
      assert_valid(self.params, {
        {
          "reason",
          optional = true,
          max_length = limits.MAX_BODY_LEN
        }
      })
      assert_error(not self.topic.locked, "topic is already locked")
      self.topic:update({
        locked = true
      })
      self:write_moderation_log("topic.lock", self.params.reason)
      return true
    end),
    unlock_topic = function(self)
      self:load_topic_for_moderation()
      assert_error(self.topic.locked, "topic is not locked")
      self.topic:update({
        locked = false
      })
      self:write_moderation_log("topic.unlock")
      return true
    end,
    stick_topic = function(self)
      self:load_topic_for_moderation()
      assert_error(not self.topic.sticky, "topic is already sticky")
      trim_filter(self.params)
      assert_valid(self.params, {
        {
          "reason",
          optional = true,
          max_length = limits.MAX_BODY_LEN
        }
      })
      self.topic:update({
        sticky = true
      })
      self:write_moderation_log("topic.stick", self.params.reason)
      return true
    end,
    unstick_topic = function(self)
      self:load_topic_for_moderation()
      assert_error(self.topic.sticky, "topic is not sticky")
      self.topic:update({
        sticky = false
      })
      self:write_moderation_log("topic.unstick")
      return true
    end,
    hide_topic = function(self)
      self:load_topic_for_moderation()
      assert_error(not self.topic:is_hidden(), "topic is already hidden")
      assert_error(not self.topic:is_archived(), "can't hide archived topic")
      trim_filter(self.params)
      assert_valid(self.params, {
        {
          "reason",
          optional = true,
          max_length = limits.MAX_BODY_LEN
        }
      })
      assert_error(self.topic:hide())
      self:write_moderation_log("topic.hide", self.params.reason)
      return true
    end,
    unhide_topic = function(self)
      self:load_topic_for_moderation()
      assert_error(self.topic:is_hidden(), "topic is not hidden")
      self.topic:set_status("default")
      self:write_moderation_log("topic.unhide")
      return true
    end,
    archive_topic = function(self)
      self:load_topic_for_moderation()
      assert_error(not self.topic:is_archived(), "topic is already archived")
      trim_filter(self.params)
      assert_valid(self.params, {
        {
          "reason",
          optional = true,
          max_length = limits.MAX_BODY_LEN
        }
      })
      self.topic:archive()
      self:write_moderation_log("topic.archive", self.params.reason)
      return true
    end,
    unarchive_topic = function(self)
      self:load_topic_for_moderation()
      assert_error(self.topic:is_archived(), "topic is not archived")
      self.topic:set_status("default")
      self:write_moderation_log("topic.unarchive")
      return true
    end,
    move_topic = function(self)
      local Categories
      Categories = require("community.models").Categories
      self:load_topic_for_moderation()
      assert_valid(self.params, {
        {
          "target_category_id",
          is_integer = true
        }
      })
      local old_category_id = self.topic.category_id
      self.target_category = Categories:find(self.params.target_category_id)
      assert_error(self.target_category:allowed_to_moderate(self.current_user), "invalid category")
      assert_error(self.topic:can_move_to(self.current_user, self.target_category))
      assert_error(self.topic:move_to_category(self.target_category))
      self:write_moderation_log("topic.move", nil, {
        category_id = old_category_id,
        data = {
          target_category_id = self.target_category.id
        }
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
    __name = "TopicsFlow",
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
  TopicsFlow = _class_0
  return _class_0
end
