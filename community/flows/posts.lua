local Flow
Flow = require("lapis.flow").Flow
local Topics, Posts, PostEdits, CommunityUsers, ActivityLogs, PendingPosts
do
  local _obj_0 = require("community.models")
  Topics, Posts, PostEdits, CommunityUsers, ActivityLogs, PendingPosts = _obj_0.Topics, _obj_0.Posts, _obj_0.PostEdits, _obj_0.CommunityUsers, _obj_0.ActivityLogs, _obj_0.PendingPosts
end
local db = require("lapis.db")
local assert_error
assert_error = require("lapis.application").assert_error
local assert_valid
assert_valid = require("lapis.validate").assert_valid
local trim_filter, slugify
do
  local _obj_0 = require("lapis.util")
  trim_filter, slugify = _obj_0.trim_filter, _obj_0.slugify
end
local require_login
require_login = require("community.helpers.app").require_login
local is_empty_html
is_empty_html = require("community.helpers.html").is_empty_html
local limits = require("community.limits")
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
      assert_valid(self.params, {
        {
          "post_id",
          is_integer = true
        }
      })
      self.post = Posts:find(self.params.post_id)
      return assert_error(self.post, "invalid post")
    end,
    new_post = require_login(function(self)
      local TopicsFlow = require("community.flows.topics")
      TopicsFlow(self):load_topic()
      assert_error(self.topic:allowed_to_post(self.current_user))
      trim_filter(self.params)
      assert_valid(self.params, {
        {
          "parent_post_id",
          optional = true,
          is_integer = true
        },
        {
          "post",
          type = "table"
        }
      })
      local new_post = trim_filter(self.params.post)
      assert_valid(new_post, {
        {
          "body",
          type = "string",
          exists = true,
          max_length = limits.MAX_BODY_LEN
        },
        {
          "body_format",
          exists = true,
          one_of = Posts.body_formats,
          optional = true
        }
      })
      assert_error(not is_empty_html(new_post.body), "body must be provided")
      local parent_post
      do
        local pid = self.params.parent_post_id
        if pid then
          parent_post = Posts:find(pid)
        end
      end
      if parent_post then
        assert_error(parent_post.topic_id == self.topic.id, "topic id mismatch (" .. tostring(parent_post.topic_id) .. " != " .. tostring(self.topic.id) .. ")")
        assert_error(parent_post:allowed_to_reply(self.current_user), "can't reply to post")
      end
      if self.topic:post_needs_approval() then
        self.pending_post = PendingPosts:create({
          user_id = self.current_user.id,
          topic_id = self.topic.id,
          category_id = self.topic.category_id,
          body = new_post.body,
          body_format = (function()
            if new_post.body_format then
              return Posts.body_formats:for_db(new_post.body_format)
            end
          end)(),
          parent_post = parent_post
        })
      else
        self.post = Posts:create({
          user_id = self.current_user.id,
          topic_id = self.topic.id,
          body = new_post.body,
          body_format = (function()
            if new_post.body_format then
              return Posts.body_formats:for_db(new_post.body_format)
            end
          end)(),
          parent_post = parent_post
        })
        self.topic:increment_from_post(self.post)
        CommunityUsers:for_user(self.current_user):increment("posts_count")
        self.topic:increment_participant(self.current_user)
        ActivityLogs:create({
          user_id = self.current_user.id,
          object = self.post,
          action = "create"
        })
      end
      return true
    end),
    edit_post = require_login(function(self)
      self:load_post()
      assert_error(self.post:allowed_to_edit(self.current_user, "edit"), "not allowed to edit")
      assert_valid(self.params, {
        {
          "post",
          type = "table"
        }
      })
      self.topic = self.post:get_topic()
      local update_tags = self.params.post.tags
      local post_update = trim_filter(self.params.post)
      assert_valid(post_update, {
        {
          "body",
          exists = true,
          max_length = limits.MAX_BODY_LEN
        },
        {
          "body_format",
          exists = true,
          one_of = Posts.body_formats,
          optional = true
        },
        {
          "reason",
          optional = true,
          max_length = limits.MAX_BODY_LEN
        }
      })
      assert_error(not is_empty_html(post_update.body), "body must be provided")
      local edited
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
          edits_count = db.raw("edits_count + 1"),
          last_edited_at = db.format_date(),
          body_format = (function()
            if post_update.body_format then
              return Posts.body_formats:for_db(post_update.body_format)
            end
          end)()
        })
        edited = true
      end
      if self.post:is_topic_post() and not self.topic.permanent then
        assert_valid(post_update, {
          {
            "title",
            optional = true,
            max_length = limits.MAX_TITLE_LEN
          },
          {
            "tags",
            optional = true,
            type = "string"
          }
        })
        local opts = { }
        if post_update.title then
          opts.title = post_update.title
          opts.slug = slugify(post_update.title)
        end
        if update_tags then
          local category = self.topic:get_category()
          local tags = category:parse_tags(post_update.tags)
          if tags and next(tags) then
            opts.tags = db.array((function()
              local _accum_0 = { }
              local _len_0 = 1
              for _index_0 = 1, #tags do
                local t = tags[_index_0]
                _accum_0[_len_0] = t.slug
                _len_0 = _len_0 + 1
              end
              return _accum_0
            end)())
          else
            opts.tags = db.NULL
          end
        end
        local filter_update
        filter_update = require("community.helpers.models").filter_update
        self.topic:update(filter_update(self.topic, opts))
      end
      if edited then
        ActivityLogs:create({
          user_id = self.current_user.id,
          object = self.post,
          action = "edit"
        })
      end
      return true
    end),
    delete_pending_post = require_login(function(self)
      assert_valid(self.params, {
        {
          "post_id",
          is_integer = true
        }
      })
      self.pending_post = assert_error(PendingPosts:find(self.params.post_id))
      assert_error(self.pending_post:allowed_to_edit(self.current_user, "delete"), "not allowed to edit")
      self.pending_post:delete()
      return true
    end),
    delete_post = require_login(function(self)
      self:load_post()
      assert_error(self.post:allowed_to_edit(self.current_user, "delete"), "not allowed to edit")
      self.topic = self.post:get_topic()
      if self.post:is_topic_post() and not self.topic.permanent then
        local TopicsFlow = require("community.flows.topics")
        TopicsFlow(self):delete_topic()
        return true
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
        return true
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
