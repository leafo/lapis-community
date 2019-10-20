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
local slugify
slugify = require("lapis.util").slugify
local require_login
require_login = require("community.helpers.app").require_login
local is_empty_html
is_empty_html = require("community.helpers.html").is_empty_html
local limits = require("community.limits")
local shapes = require("community.helpers.shapes")
local types
types = require("tableshape").types
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
      local params = shapes.assert_valid(self.params, {
        {
          "post_id",
          shapes.db_id
        }
      })
      self.post = Posts:find(params.post_id)
      return assert_error(self.post, "invalid post")
    end,
    new_post = require_login(function(self)
      local TopicsFlow = require("community.flows.topics")
      TopicsFlow(self):load_topic()
      assert_error(self.topic:allowed_to_post(self.current_user, self._req))
      local params = shapes.assert_valid(self.params, {
        {
          "parent_post_id",
          shapes.db_id + shapes.empty
        }
      })
      local new_post = shapes.assert_valid(self.params.post, {
        {
          "body",
          shapes.limited_text(limits.MAX_BODY_LEN)
        },
        {
          "body_format",
          shapes.db_enum(Posts.body_formats) + shapes.empty / Posts.body_formats.html
        }
      })
      local body = assert_error(Posts:filter_body(new_post.body, new_post.body_format))
      local parent_post
      do
        local pid = params.parent_post_id
        if pid then
          parent_post = assert_error(Posts:find(pid), "invalid parent post")
        end
      end
      if parent_post then
        assert_error(parent_post.topic_id == self.topic.id, "parent post doesn't belong to same topic")
        assert_error(parent_post:allowed_to_reply(self.current_user, self._req), "can't reply to post")
      end
      if self.topic:post_needs_approval() then
        self.pending_post = PendingPosts:create({
          user_id = self.current_user.id,
          topic_id = self.topic.id,
          category_id = self.topic.category_id,
          body = body,
          body_format = new_post.body_format,
          parent_post_id = parent_post and parent_post.id
        })
      else
        self.post = Posts:create({
          user_id = self.current_user.id,
          topic_id = self.topic.id,
          body = body,
          body_format = new_post.body_format,
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
        self.post:on_body_updated_callback(self)
      end
      return true
    end),
    edit_post = require_login(function(self)
      self:load_post()
      assert_error(self.post:allowed_to_edit(self.current_user, "edit"), "not allowed to edit")
      self.topic = self.post:get_topic()
      local post_update = shapes.assert_valid(self.params.post, {
        {
          "body",
          shapes.limited_text(limits.MAX_BODY_LEN)
        },
        {
          "body_format",
          shapes.db_enum(Posts.body_formats) + shapes.empty / Posts.body_formats.html
        },
        {
          "reason",
          shapes.empty + shapes.limited_text(limits.MAX_BODY_LEN)
        }
      })
      local body = assert_error(Posts:filter_body(post_update.body, post_update.body_format))
      local edited
      if self.post.body ~= body then
        PostEdits:create({
          user_id = self.current_user.id,
          body_before = self.post.body,
          body_format = self.post.body_format,
          reason = post_update.reason,
          post_id = self.post.id
        })
        self.post:update({
          body = body,
          edits_count = db.raw("edits_count + 1"),
          last_edited_at = db.format_date(),
          body_format = post_update.body_format
        })
        edited = true
      end
      local edited_title
      if self.post:is_topic_post() and not self.topic.permanent then
        local category = self.topic:get_category()
        local topic_update = shapes.assert_valid(self.params.post, {
          {
            "tags",
            shapes.empty + shapes.limited_text(240) / (category and (function()
              local _base_1 = category
              local _fn_0 = _base_1.parse_tags
              return function(...)
                return _fn_0(_base_1, ...)
              end
            end)() or nil)
          },
          {
            "title",
            types["nil"] + shapes.limited_text(limits.MAX_TITLE_LEN)
          }
        })
        if topic_update.title then
          topic_update.slug = slugify(topic_update.title)
        end
        if self.params.post.tags then
          if topic_update.tags and next(topic_update.tags) then
            topic_update.tags = db.array((function()
              local _accum_0 = { }
              local _len_0 = 1
              local _list_0 = topic_update.tags
              for _index_0 = 1, #_list_0 do
                local t = _list_0[_index_0]
                _accum_0[_len_0] = t.slug
                _len_0 = _len_0 + 1
              end
              return _accum_0
            end)())
          else
            topic_update.tags = db.NULL
          end
        end
        local filter_update
        filter_update = require("community.helpers.models").filter_update
        topic_update = filter_update(self.topic, topic_update)
        self.topic:update(topic_update)
        edited_title = topic_update.title and true
      end
      if edited or edited_title then
        self.post:on_body_updated_callback(self)
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
      local params = shapes.assert_valid(self.params, {
        {
          "post_id",
          shapes.db_id
        }
      })
      self.pending_post = assert_error(PendingPosts:find(params.post_id))
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
