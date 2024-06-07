local db = require("lapis.db")
local Flow
Flow = require("lapis.flow").Flow
local Topics, Posts, CommunityUsers, ActivityLogs, PendingPosts
do
  local _obj_0 = require("community.models")
  Topics, Posts, CommunityUsers, ActivityLogs, PendingPosts = _obj_0.Topics, _obj_0.Posts, _obj_0.CommunityUsers, _obj_0.ActivityLogs, _obj_0.PendingPosts
end
local assert_valid
assert_valid = require("lapis.validate").assert_valid
local assert_error, yield_error
do
  local _obj_0 = require("lapis.application")
  assert_error, yield_error = _obj_0.assert_error, _obj_0.yield_error
end
local require_current_user
require_current_user = require("community.helpers.app").require_current_user
local is_empty_html
is_empty_html = require("community.helpers.html").is_empty_html
local limits = require("community.limits")
local shapes = require("community.helpers.shapes")
local types = require("lapis.validate.types")
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
      local params = assert_valid(self.params, types.params_shape({
        {
          "topic_id",
          types.db_id
        }
      }))
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
    new_topic = require_current_user(function(self, opts)
      if opts == nil then
        opts = { }
      end
      local CategoriesFlow = require("community.flows.categories")
      local PollsFlow = require("community.flows.topic_polls")
      CategoriesFlow(self):load_category()
      local poll_flow = PollsFlow(self)
      local new_topic = assert_valid(self.params.topic, types.params_shape({
        {
          "title",
          types.limited_text(limits.MAX_TITLE_LEN)
        },
        {
          "body",
          types.limited_text(limits.MAX_BODY_LEN)
        },
        {
          "body_format",
          shapes.default("html") * types.db_enum(Posts.body_formats)
        },
        {
          "tags",
          types.empty + types.limited_text(240) / (function()
            local _base_1 = self.category
            local _fn_0 = _base_1.parse_tags
            return function(...)
              return _fn_0(_base_1, ...)
            end
          end)()
        },
        {
          "sticky",
          types.empty / false + types.any / true
        },
        {
          "locked",
          types.empty / false + types.any / true
        },
        {
          "poll",
          types.empty + types.table
        }
      }))
      if new_topic.poll then
        local new_poll
        new_poll = assert_valid(self.params.topic, types.params_shape({
          {
            "poll",
            poll_flow:validate_params_shape()
          }
        })).poll
        new_topic.poll = new_poll
        assert_error(self.category:allowed_to_create_poll(self.current_user), "you can't create a poll in this category")
      end
      local body = assert_error(Posts:filter_body(new_topic.body, new_topic.body_format))
      local community_user = CommunityUsers:for_user(self.current_user)
      assert_error(self.category:allowed_to_post_topic(self.current_user, self._req))
      local can_post, err, warning = community_user:allowed_to_post(self.category)
      if not (can_post) then
        self.warning = warning
        yield_error(err or "your account is not able to post at this time")
      end
      local sticky = false
      local locked = false
      local moderator = self.category:allowed_to_moderate(self.current_user)
      if moderator then
        sticky = new_topic.sticky
        locked = new_topic.locked
      end
      local needs_approval
      if opts.force_pending then
        needs_approval, warning = true
      else
        needs_approval, warning = self.category:topic_needs_approval(self.current_user, {
          title = new_topic.title,
          category_id = self.category.id,
          body_format = new_topic.body_format,
          body = body
        })
      end
      local create_params = {
        needs_approval = needs_approval,
        title = new_topic.title,
        body_format = new_topic.body_format,
        body = body,
        sticky = sticky,
        locked = locked,
        tags = (function()
          if new_topic.tags and next(new_topic.tags) then
            local _accum_0 = { }
            local _len_0 = 1
            local _list_0 = new_topic.tags
            for _index_0 = 1, #_list_0 do
              local t = _list_0[_index_0]
              _accum_0[_len_0] = t.slug
              _len_0 = _len_0 + 1
            end
            return _accum_0
          end
        end)()
      }
      if opts.before_create_callback then
        opts.before_create_callback(create_params)
      end
      if create_params.needs_approval then
        self.warning = warning
        local metadata = {
          locked = (function()
            if create_params.locked then
              return create_params.locked
            end
          end)(),
          sticky = (function()
            if create_params.sticky then
              return create_params.sticky
            end
          end)(),
          topic_tags = create_params.tags,
          note = create_params.approval_note
        }
        if not (next(metadata)) then
          metadata = nil
        end
        self.pending_post = PendingPosts:create({
          user_id = self.current_user.id,
          category_id = self.category.id,
          title = create_params.title,
          body_format = create_params.body_format,
          body = create_params.body,
          data = metadata
        })
        ActivityLogs:create({
          user_id = self.current_user.id,
          object = self.pending_post,
          action = "create_topic",
          data = {
            category_id = self.category.id
          }
        })
        return true
      end
      self.topic = Topics:create({
        user_id = self.current_user.id,
        category_id = self.category.id,
        title = create_params.title,
        tags = create_params.tags and db.array(create_params.tags),
        category_order = self.category:next_topic_category_order(),
        sticky = create_params.sticky,
        locked = create_params.locked
      })
      self.post = Posts:create({
        user_id = self.current_user.id,
        topic_id = self.topic.id,
        body_format = create_params.body_format,
        body = create_params.body
      })
      self.topic:increment_from_post(self.post, {
        update_category_order = false
      })
      self.category:increment_from_topic(self.topic)
      community_user:increment_from_post(self.post, true)
      self.topic:increment_participant(self.current_user)
      self.post:on_body_updated_callback(self)
      ActivityLogs:create({
        user_id = self.current_user.id,
        object = self.topic,
        action = "create"
      })
      if new_topic.poll then
        poll_flow:set_poll(self.topic, new_topic.poll)
      end
      return true
    end),
    delete_topic = require_current_user(function(self)
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
          local params = assert_valid(self.params, types.params_shape({
            {
              "reason",
              types.empty + types.limited_text(limits.MAX_BODY_LEN)
            }
          }))
          self:write_moderation_log("topic.delete", params.reason)
        end
        return true
      end
    end),
    lock_topic = require_current_user(function(self)
      self:load_topic_for_moderation()
      local params = assert_valid(self.params, types.params_shape({
        {
          "reason",
          types.empty + types.limited_text(limits.MAX_BODY_LEN)
        }
      }))
      assert_error(not self.topic.locked, "topic is already locked")
      self.topic:update({
        locked = true
      })
      self:write_moderation_log("topic.lock", params.reason)
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
      local params = assert_valid(self.params, types.params_shape({
        {
          "reason",
          types.empty + types.limited_text(limits.MAX_BODY_LEN)
        }
      }))
      self.topic:update({
        sticky = true
      })
      self:write_moderation_log("topic.stick", params.reason)
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
      local params = assert_valid(self.params, types.params_shape({
        {
          "reason",
          types.empty + types.limited_text(limits.MAX_BODY_LEN)
        }
      }))
      assert_error(self.topic:hide())
      self:write_moderation_log("topic.hide", params.reason)
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
      local params = assert_valid(self.params, types.params_shape({
        {
          "reason",
          types.empty + types.limited_text(limits.MAX_BODY_LEN)
        }
      }))
      self.topic:archive()
      self:write_moderation_log("topic.archive", params.reason)
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
      local params = assert_valid(self.params, types.params_shape({
        {
          "target_category_id",
          types.db_id
        }
      }))
      local old_category_id = self.topic.category_id
      self.target_category = Categories:find(params.target_category_id)
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
