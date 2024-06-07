local Flow
Flow = require("lapis.flow").Flow
local Topics, Posts, PostEdits, CommunityUsers, ActivityLogs, PendingPosts
do
  local _obj_0 = require("community.models")
  Topics, Posts, PostEdits, CommunityUsers, ActivityLogs, PendingPosts = _obj_0.Topics, _obj_0.Posts, _obj_0.PostEdits, _obj_0.CommunityUsers, _obj_0.ActivityLogs, _obj_0.PendingPosts
end
local db = require("lapis.db")
local assert_error, yield_error
do
  local _obj_0 = require("lapis.application")
  assert_error, yield_error = _obj_0.assert_error, _obj_0.yield_error
end
local assert_valid
assert_valid = require("lapis.validate").assert_valid
local slugify
slugify = require("lapis.util").slugify
local require_current_user
require_current_user = require("community.helpers.app").require_current_user
local limits = require("community.limits")
local types = require("lapis.validate.types")
local PostsFlow
do
  local _class_0
  local _parent_0 = Flow
  local _base_0 = {
    expose_assigns = true,
    load_post = function(self)
      if self.post then
        return 
      end
      local params = assert_valid(self.params, types.params_shape({
        {
          "post_id",
          types.db_id
        }
      }))
      self.post = Posts:find(params.post_id)
      return assert_error(self.post, "invalid post")
    end,
    new_post = require_current_user(function(self, opts)
      if opts == nil then
        opts = { }
      end
      local TopicsFlow = require("community.flows.topics")
      TopicsFlow(self):load_topic()
      local community_user = CommunityUsers:for_user(self.current_user)
      assert_error(self.topic:allowed_to_post(self.current_user, self._req))
      local can_post, posting_err, warning = community_user:allowed_to_post(self.topic)
      if not (can_post) then
        self.warning = warning
        yield_error(posting_err or "your account is not able to post at this time")
      end
      local new_post, parent_post_id
      do
        local _obj_0 = assert_valid(self.params, types.params_shape({
          {
            "parent_post_id",
            types.db_id + types.empty
          },
          {
            "post",
            types.params_shape({
              {
                "body",
                types.limited_text(limits.MAX_BODY_LEN)
              },
              {
                "body_format",
                types.db_enum(Posts.body_formats) + types.empty / Posts.body_formats.html
              }
            })
          }
        }))
        new_post, parent_post_id = _obj_0.post, _obj_0.parent_post_id
      end
      local body = assert_error(Posts:filter_body(new_post.body, new_post.body_format))
      local parent_post
      do
        local pid = parent_post_id
        if pid then
          parent_post = assert_error(Posts:find(pid), "invalid parent post")
        end
      end
      if parent_post then
        assert_error(parent_post.topic_id == self.topic.id, "parent post doesn't belong to same topic")
        assert_error(parent_post:allowed_to_reply(self.current_user, self._req), "can't reply to post")
        local viewer = parent_post:with_viewing_user(self.current_user.id)
        do
          local block = viewer:get_block_received()
          if block then
            self.block = block
            yield_error("can't reply to post")
          end
        end
      end
      local needs_approval
      if opts.force_pending then
        needs_approval, warning = true
      else
        needs_approval, warning = self.topic:post_needs_approval(self.current_user, {
          body = body,
          topic_id = self.topic.id,
          body_format = new_post.body_format,
          parent_post_id = parent_post and parent_post.id
        })
      end
      local create_params = {
        needs_approval = needs_approval,
        body = body,
        body_format = new_post.body_format,
        parent_post_id = parent_post and parent_post.id
      }
      if opts.before_create_callback then
        opts.before_create_callback(create_params)
      end
      if create_params.needs_approval then
        self.warning = warning
        local metadata = {
          note = create_params.approval_note
        }
        if not (next(metadata)) then
          metadata = nil
        end
        self.pending_post = PendingPosts:create({
          user_id = self.current_user.id,
          topic_id = self.topic.id,
          category_id = self.topic.category_id,
          body = create_params.body,
          body_format = create_params.body_format,
          parent_post_id = create_params.parent_post_id,
          data = metadata
        })
        ActivityLogs:create({
          user_id = self.current_user.id,
          object = self.pending_post,
          action = "create_post",
          data = {
            topic_id = self.topic.id,
            category_id = self.topic.category_id,
            parent_post_id = self.pending_post.parent_post_id
          }
        })
        return true
      end
      self.post = Posts:create({
        user_id = self.current_user.id,
        topic_id = self.topic.id,
        body = create_params.body,
        body_format = create_params.body_format,
        parent_post_id = create_params.parent_post_id
      })
      self.topic:increment_from_post(self.post)
      community_user:increment_from_post(self.post)
      self.topic:increment_participant(self.current_user)
      ActivityLogs:create({
        user_id = self.current_user.id,
        object = self.post,
        action = "create"
      })
      self.post:on_body_updated_callback(self)
      return true
    end),
    edit_post = require_current_user(function(self, opts)
      self:load_post()
      assert_error(self.post:allowed_to_edit(self.current_user, "edit"), "not allowed to edit")
      self.topic = self.post:get_topic()
      local is_topic_post = self.post:is_topic_post() and not self.topic.permanent
      local v = {
        {
          "body",
          types.limited_text(limits.MAX_BODY_LEN)
        },
        {
          "body_format",
          types.db_enum(Posts.body_formats) + types.empty / Posts.body_formats.html
        },
        {
          "reason",
          types.empty + types.limited_text(limits.MAX_BODY_LEN)
        }
      }
      if is_topic_post then
        local category = self.topic:get_category()
        table.insert(v, {
          "title",
          types["nil"] + types.limited_text(limits.MAX_TITLE_LEN)
        })
        table.insert(v, {
          "tags",
          types["nil"] + types.empty / (function()
            return { }
          end) + types.limited_text(240) / (category and (function()
            local _base_1 = category
            local _fn_0 = _base_1.parse_tags
            return function(...)
              return _fn_0(_base_1, ...)
            end
          end)() or nil)
        })
        table.insert(v, {
          "poll",
          types.empty + types.table
        })
      end
      local post_update = assert_valid(self.params.post, types.params_shape(v))
      post_update.body = assert_error(Posts:filter_body(post_update.body, post_update.body_format))
      local poll_flow
      if post_update.poll then
        local PollsFlow = require("community.flows.topic_polls")
        poll_flow = PollsFlow(self)
        local poll_edit
        poll_edit = assert_valid(self.params.topic, types.params_shape({
          {
            "poll",
            poll_flow:validate_params_shape()
          }
        })).poll
        post_update.poll = poll_edit
      end
      if opts and opts.before_edit_callback then
        opts.before_edit_callback(post_update)
      end
      local edited_body
      if self.post.body ~= post_update.body then
        PostEdits:create({
          user_id = self.current_user.id,
          body_before = self.post.body,
          body_format = self.post.body_format,
          reason = post_update.reason,
          post_id = self.post.id
        })
        self.post:update({
          body = post_update.body,
          body_format = post_update.body_format,
          edits_count = db.raw("edits_count + 1"),
          last_edited_at = db.format_date()
        })
        edited_body = true
      end
      local edited_title
      if is_topic_post then
        local topic_update = {
          title = post_update.title
        }
        if topic_update.title then
          topic_update.slug = slugify(topic_update.title)
        end
        do
          local new_tags = post_update.tags
          if new_tags then
            if next(new_tags) then
              topic_update.tags = db.array((function()
                local _accum_0 = { }
                local _len_0 = 1
                for _index_0 = 1, #new_tags do
                  local t = new_tags[_index_0]
                  _accum_0[_len_0] = t.slug
                  _len_0 = _len_0 + 1
                end
                return _accum_0
              end)())
            else
              topic_update.tags = db.NULL
            end
          end
        end
        local filter_update
        filter_update = require("community.helpers.models").filter_update
        topic_update = filter_update(self.topic, topic_update)
        self.topic:update(topic_update)
        edited_title = topic_update.title and true
      end
      if edited_body or edited_title then
        self.post:on_body_updated_callback(self)
      end
      if edited_body then
        ActivityLogs:create({
          user_id = self.current_user.id,
          object = self.post,
          action = "edit"
        })
      end
      return true
    end),
    delete_post = require_current_user(function(self)
      self:load_post()
      assert_error(self.post:allowed_to_edit(self.current_user, "delete"), "not allowed to edit")
      self.topic = self.post:get_topic()
      if self.post:is_topic_post() and not self.topic.permanent then
        local TopicsFlow = require("community.flows.topics")
        TopicsFlow(self):delete_topic()
        return true, "topic"
      end
      local mode
      if self.topic:allowed_to_moderate(self.current_user) then
        if self.params.hard then
          mode = "hard"
        end
      end
      local deleted, kind = self.post:delete(mode)
      if deleted then
        self.topic:decrement_participant(self.post:get_user())
        if not (kind == "hard") then
          ActivityLogs:create({
            user_id = self.current_user.id,
            object = self.post,
            action = "delete"
          })
        end
        return true, kind
      end
    end)
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "PostsFlow",
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
  PostsFlow = _class_0
  return _class_0
end
