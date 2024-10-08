local db = require("lapis.db")
local Model, VirtualModel
do
  local _obj_0 = require("community.model")
  Model, VirtualModel = _obj_0.Model, _obj_0.VirtualModel
end
local enum
enum = require("lapis.db.model").enum
local date = require("date")
local Posts
do
  local _class_0
  local PostViewers
  local _parent_0 = Model
  local _base_0 = {
    with_viewing_user = VirtualModel:make_loader("viewing_users", function(self, user_id)
      return PostViewers:load({
        post_id = self.id,
        author_id = self.user_id,
        viewer_id = user_id
      })
    end),
    get_mentioned_users = function(self)
      if not (self.mentioned_users) then
        local usernames = self.__class:_parse_usernames(self.body)
        local CommunityUsers
        CommunityUsers = require("community.models").CommunityUsers
        self.mentioned_users = CommunityUsers:find_users_by_name(usernames)
      end
      return self.mentioned_users
    end,
    filled_body = function(self, r)
      local body = self.body
      do
        local m = self:get_mentioned_users()
        if m then
          local mentions_by_username
          do
            local _tbl_0 = { }
            for _index_0 = 1, #m do
              local u = m[_index_0]
              _tbl_0[u.username] = u
            end
            mentions_by_username = _tbl_0
          end
          local escape
          escape = require("lapis.html").escape
          body = body:gsub("@([%w-_]+)", function(username)
            local user = mentions_by_username[username]
            if not (user) then
              return "@" .. tostring(username)
            end
            return "<a href='" .. tostring(escape(r:build_url(r:url_for(user)))) .. "'>@" .. tostring(escape(user:name_for_display())) .. "</a>"
          end)
        end
      end
      return body
    end,
    is_topic_post = function(self)
      return self.post_number == 1 and self.depth == 1
    end,
    allowed_to_vote = function(self, user, direction)
      if self:is_moderation_event() then
        return false
      end
      if not (user) then
        return false
      end
      if self.deleted then
        return false
      end
      if self:is_archived() then
        return false
      end
      local topic = self:get_topic()
      do
        local category = self.topic:get_category()
        if category then
          return category:allowed_to_vote(user, direction, self)
        else
          return true
        end
      end
    end,
    allowed_to_edit = function(self, user, action)
      if action == nil then
        action = "edit"
      end
      if self.deleted and action ~= "delete" then
        return false
      end
      if not (user) then
        return false
      end
      if user:is_admin() then
        return true
      end
      if self:is_archived() then
        return false
      end
      if user.id == self.user_id then
        return true
      end
      if self:is_protected() then
        return false
      end
      if action ~= "delete" and self.deleted then
        return false
      end
      local topic = self:get_topic()
      if topic:allowed_to_moderate(user) then
        return true
      end
      return false
    end,
    allowed_to_reply = function(self, user, req)
      if self.deleted then
        return false
      end
      if self:is_moderation_event() then
        return false
      end
      if not (user) then
        return false
      end
      if not (self:is_default()) then
        return false
      end
      local topic = self:get_topic()
      return topic:allowed_to_post(user, req)
    end,
    should_soft_delete = function(self)
      if self:is_moderation_event() then
        return false
      end
      if self:get_has_children() then
        return true
      end
      if self.depth > 1 and self:get_has_next_post() then
        return true
      end
      local delta = date.diff(date(true), date(self.created_at))
      return delta:spanminutes() > 10
    end,
    delete = function(self, force)
      self.topic = self:get_topic()
      do
        local search = self:get_posts_search()
        if search then
          search:delete()
        end
      end
      if self:is_topic_post() and not self.topic.permanent then
        return self.topic:delete(force), "topic"
      end
      if force ~= "soft" and (force == "hard" or not self:should_soft_delete()) then
        return self:hard_delete(), "hard"
      end
      return self:soft_delete(), "soft"
    end,
    soft_delete = function(self)
      local soft_delete
      soft_delete = require("community.helpers.models").soft_delete
      if soft_delete(self) then
        self:update({
          deleted_at = db.format_date()
        }, {
          timestamp = false
        })
        local CommunityUsers, Topics, CategoryPostLogs
        do
          local _obj_0 = require("community.models")
          CommunityUsers, Topics, CategoryPostLogs = _obj_0.CommunityUsers, _obj_0.Topics, _obj_0.CategoryPostLogs
        end
        if not (self:is_moderation_event()) then
          CommunityUsers:increment(self.user_id, "posts_count", -1)
          CategoryPostLogs:clear_post(self)
          do
            local topic = self:get_topic()
            if topic then
              if topic.last_post_id == self.id then
                topic:refresh_last_post()
              end
              do
                local category = topic:get_category()
                if category then
                  do
                    category.last_topic_id = topic.id
                    if category.last_topic_id then
                      category:refresh_last_topic()
                    end
                  end
                end
              end
              topic:increment_counter("deleted_posts_count", 1)
            end
          end
        end
        return true
      end
    end,
    hard_delete = function(self, deleted_topic)
      local deleted, res = Model.delete(self, db.raw("*"))
      if not (deleted) then
        return false
      end
      local deleted_post = unpack(res)
      local was_soft_deleted = deleted_post.deleted
      local CommunityUsers, PostEdits, PostReports, Votes, ActivityLogs, CategoryPostLogs
      do
        local _obj_0 = require("community.models")
        CommunityUsers, PostEdits, PostReports, Votes, ActivityLogs, CategoryPostLogs = _obj_0.CommunityUsers, _obj_0.PostEdits, _obj_0.PostReports, _obj_0.Votes, _obj_0.ActivityLogs, _obj_0.CategoryPostLogs
      end
      if not was_soft_deleted and not self:is_moderation_event() then
        local t = deleted_topic or self:get_topic()
        CommunityUsers:increment(self.user_id, "posts_count", -1)
        CategoryPostLogs:clear_post(self)
      end
      local orphans = self.__class:select("where parent_post_id = ?", self.id)
      do
        local topic = self:get_topic()
        if topic then
          topic:renumber_posts(self:get_parent_post())
          if topic.last_post_id == self.id then
            topic:refresh_last_post()
          end
          do
            local category = topic:get_category()
            if category then
              do
                category.last_topic_id = topic.id
                if category.last_topic_id then
                  category:refresh_last_topic()
                end
              end
            end
          end
          if was_soft_deleted and not self:is_moderation_event() then
            topic:increment_counter("deleted_posts_count", -1)
          end
          local posts_count
          if not (self:is_moderation_event()) then
            posts_count = db.raw("posts_count - 1")
          end
          local root_posts_count
          if self.depth == 1 then
            root_posts_count = db.raw("root_posts_count - 1")
          end
          topic:update({
            posts_count = posts_count,
            root_posts_count = root_posts_count
          }, {
            timestamp = false
          })
          if root_posts_count then
            topic:on_increment_callback("root_posts_count", -1)
          end
          if posts_count then
            topic:on_increment_callback("posts_count", -1)
          end
        end
      end
      local _list_0 = {
        PostEdits
      }
      for _index_0 = 1, #_list_0 do
        local model = _list_0[_index_0]
        db.delete(model:table_name(), {
          post_id = self.id
        })
      end
      local _list_1 = {
        Votes,
        ActivityLogs
      }
      for _index_0 = 1, #_list_1 do
        local model = _list_1[_index_0]
        db.delete(model:table_name(), {
          object_type = model.object_types.post,
          object_id = self.id
        })
      end
      for _index_0 = 1, #orphans do
        local orphan_post = orphans[_index_0]
        orphan_post:hard_delete()
      end
      return true
    end,
    allowed_to_report = function(self, user, req)
      if self.deleted then
        return false
      end
      if self:is_moderation_event() then
        return false
      end
      if not (user) then
        return false
      end
      if user.id == self.user_id then
        return false
      end
      if not (self:is_default()) then
        return false
      end
      if not (self:allowed_to_view(user, req)) then
        return false
      end
      return true
    end,
    allowed_to_view = function(self, user, req)
      return self:get_topic():allowed_to_view(user, req)
    end,
    notification_targets = function(self, extra_targets)
      if self:is_moderation_event() then
        return { }
      end
      local targets = { }
      local _list_0 = self:get_mentioned_users()
      for _index_0 = 1, #_list_0 do
        local user = _list_0[_index_0]
        local _update_0 = user.id
        targets[_update_0] = targets[_update_0] or {
          "mention",
          user.id
        }
      end
      do
        local parent = self:get_parent_post()
        if parent then
          targets[parent.user_id] = {
            "reply",
            parent:get_user(),
            parent
          }
        end
      end
      local topic = self:get_topic()
      local _list_1 = topic:notification_target_users()
      for _index_0 = 1, #_list_1 do
        local target_user = _list_1[_index_0]
        local _update_0 = target_user.id
        targets[_update_0] = targets[_update_0] or {
          "post",
          target_user,
          topic
        }
      end
      do
        local category = self:is_topic_post() and topic:get_category()
        if category then
          local _list_2 = category:notification_target_users()
          for _index_0 = 1, #_list_2 do
            local target_user = _list_2[_index_0]
            local _update_0 = target_user.id
            targets[_update_0] = targets[_update_0] or {
              "topic",
              target_user,
              category,
              topic
            }
          end
          local category_group = category:get_category_group()
          if category_group then
            local _list_3 = category_group:notification_target_users()
            for _index_0 = 1, #_list_3 do
              local target_user = _list_3[_index_0]
              local _update_0 = target_user.id
              targets[_update_0] = targets[_update_0] or {
                "topic",
                target_user,
                category_group,
                topic
              }
            end
          end
        end
      end
      if extra_targets then
        for _index_0 = 1, #extra_targets do
          local t = extra_targets[_index_0]
          local user = t[2]
          local _update_0 = user.id
          targets[_update_0] = targets[_update_0] or t
        end
      end
      targets[self.user_id] = nil
      local _accum_0 = { }
      local _len_0 = 1
      for _, v in pairs(targets) do
        _accum_0[_len_0] = v
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end,
    get_ancestors = function(self)
      if not (self.ancestors) then
        if self.depth == 1 then
          self.ancestors = { }
          return self.ancestors
        end
        local tname = db.escape_identifier(self.__class:table_name())
        self.ancestors = db.query("\n        with recursive nested as (\n          (select * from " .. tostring(tname) .. " where id = ?)\n          union\n          select pr.* from " .. tostring(tname) .. " pr, nested\n            where pr.id = nested.parent_post_id\n        )\n        select * from nested\n      ", self.parent_post_id)
        local _list_0 = self.ancestors
        for _index_0 = 1, #_list_0 do
          local post = _list_0[_index_0]
          self.__class:load(post)
        end
        table.sort(self.ancestors, function(a, b)
          return a.depth > b.depth
        end)
      end
      return self.ancestors
    end,
    get_root_ancestor = function(self)
      local ancestors = self:get_ancestors()
      return ancestors[#ancestors]
    end,
    has_replies = function(self)
      return error("deprecated method, use: post\\get_has_children")
    end,
    set_status = function(self, status)
      self:update({
        status = self.__class.statuses:for_db(status)
      })
      local CategoryPostLogs
      CategoryPostLogs = require("community.models").CategoryPostLogs
      if self.status == self.__class.statuses.default then
        CategoryPostLogs:log_post(self)
      else
        CategoryPostLogs:clear_post(self)
      end
      local topic = self:get_topic()
      if topic.last_post_id == self.id then
        return topic:refresh_last_post()
      end
    end,
    archive = function(self)
      if not (self.status == self.__class.statuses.default) then
        return nil
      end
      if not (self.depth == 1) then
        return nil, "can only archive root post"
      end
      self:set_status("archived")
      return true
    end,
    is_archived = function(self)
      return self.status == self.__class.statuses.archived
    end,
    is_default = function(self)
      return self.status == self.__class.statuses.default
    end,
    is_protected = function(self)
      return self:get_topic():is_protected()
    end,
    vote_score = function(self)
      return self.up_votes_count - self.down_votes_count
    end,
    on_vote_callback = function(self, kind, vote)
      local field_name
      if vote.positive then
        field_name = "up_votes_count"
      else
        field_name = "down_votes_count"
      end
      local value_update
      local _exp_0 = kind
      if "increment" == _exp_0 then
        value_update = db.raw(tostring(db.escape_identifier(field_name)) .. " + " .. tostring(db.escape_literal(vote:score_adjustment())))
      elseif "decrement" == _exp_0 then
        value_update = db.raw(tostring(db.escape_identifier(field_name)) .. " - " .. tostring(db.escape_literal(vote:score_adjustment())))
      else
        value_update = error("unknown vote callback kind: " .. tostring(kind))
      end
      self:update({
        [field_name] = value_update
      })
      local CommunityUsers
      CommunityUsers = require("community.models").CommunityUsers
      local user_field_name
      if vote.positive then
        user_field_name = "received_up_votes_count"
      else
        user_field_name = "received_down_votes_count"
      end
      local _exp_1 = kind
      if "increment" == _exp_1 then
        CommunityUsers:increment(self.user_id, user_field_name, vote:score_adjustment())
      elseif "decrement" == _exp_1 then
        CommunityUsers:increment(self.user_id, user_field_name, -vote:score_adjustment())
      end
      do
        local topic = self:is_topic_post() and self:get_topic()
        if topic then
          topic.topic_post = self
          local category = topic:get_category()
          if category and category:order_by_score() then
            return topic:update({
              category_order = topic:calculate_score_category_order()
            })
          end
        end
      end
    end,
    is_moderation_event = function(self)
      return not not self.moderation_log_id
    end,
    on_body_updated_callback = function(self, req_or_flow)
      return self:refresh_search_index()
    end,
    refresh_search_index = function(self)
      local search = self:get_posts_search()
      if self:should_index_for_search() then
        local PostsSearch
        PostsSearch = require("community.models").PostsSearch
        return PostsSearch:index_post(self)
      else
        if search then
          return search:delete()
        end
      end
    end,
    pin_to = function(self, position)
      assert(position, "missing position to pin to")
      local topic = self:get_topic()
      topic:reposition_post(self, position)
      return self:update({
        pin_position = position
      })
    end,
    unpin = function(self)
      assert(self:is_pinned())
      local after = unpack(self.__class:select("\n      where created_at > ? and " .. tostring(db.encode_clause({
        topic_id = self.topic_id,
        parent_post_id = self.parent_post_id or db.NULL,
        pin_position = db.NULL,
        depth = self.depth
      })) .. " limit 1\n    ", self.created_at, {
        fields = "post_number"
      }))
      if after then
        local topic = self:get_topic()
        topic:reposition_post(self, after.post_number - 1)
        return self:update({
          pin_position = db.NULL
        })
      else
        local number_cond = {
          topic_id = self.topic_id,
          depth = self.depth,
          parent_post_id = self.parent_post_id or db.NULL
        }
        local post_number = db.interpolate_query("\n       (select coalesce(max(post_number), 0) from " .. tostring(db.escape_identifier(self.__class:table_name())) .. "\n         where " .. tostring(db.encode_clause(number_cond)) .. ") + 1\n      ")
        self:update({
          pin_position = db.NULL,
          post_number = db.raw(post_number)
        })
        return self:get_topic():renumber_posts()
      end
    end,
    is_pinned = function(self)
      return not not self.pin_position
    end,
    should_index_for_search = function(self)
      if self.deleted then
        return false
      end
      if self.moderation_log_id then
        return false
      end
      if self.status == self.__class.statuses.spam then
        return false
      end
      local topic = self:get_topic()
      if not topic or topic.deleted then
        return false
      end
      return nil
    end,
    get_block = function(self, user)
      if user then
        return self:with_viewing_user(user.id):get_block_given()
      end
    end,
    get_vote = function(self, user)
      if user then
        if (self.down_votes_count or 0) > 0 or (self.up_votes_count or 0) > 0 or self.user_id == user.id then
          return self:with_viewing_user(user.id):get_vote()
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
    __name = "Posts",
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
  do
    local _class_1
    local _parent_1 = VirtualModel
    local _base_1 = {
      can_be_blocked = function(self)
        do
          local viewer = self:get_viewer()
          if viewer then
            if viewer:is_admin() then
              return false
            end
            do
              local post = self:get_post()
              if post then
                do
                  local topic = post:get_topic()
                  if topic then
                    if topic:allowed_to_moderate(viewer) then
                      return false
                    end
                  end
                end
              end
            end
          end
        end
        return true
      end
    }
    _base_1.__index = _base_1
    setmetatable(_base_1, _parent_1.__base)
    _class_1 = setmetatable({
      __init = function(self, ...)
        return _class_1.__parent.__init(self, ...)
      end,
      __base = _base_1,
      __name = "PostViewers",
      __parent = _parent_1
    }, {
      __index = function(cls, name)
        local val = rawget(_base_1, name)
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
        local _self_0 = setmetatable({}, _base_1)
        cls.__init(_self_0, ...)
        return _self_0
      end
    })
    _base_1.__class = _class_1
    local self = _class_1
    self.primary_key = {
      "post_id",
      "author_id",
      "viewer_id"
    }
    self.relations = {
      {
        "viewer",
        belongs_to = "Users"
      },
      {
        "author",
        belongs_to = "Users"
      },
      {
        "post",
        belongs_to = "Posts"
      },
      {
        "block_given",
        has_one = "Blocks",
        key = {
          blocking_user_id = "viewer_id",
          blocked_user_id = "author_id"
        }
      },
      {
        "block_received",
        has_one = "Blocks",
        key = {
          blocking_user_id = "author_id",
          blocked_user_id = "viewer_id"
        }
      },
      {
        "vote",
        has_one = "Votes",
        key = {
          object_id = "post_id",
          user_id = "viewer_id"
        },
        where = {
          object_type = 1
        }
      }
    }
    if _parent_1.__inherited then
      _parent_1.__inherited(_parent_1, _class_1)
    end
    PostViewers = _class_1
  end
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
      "edits",
      has_many = "PostEdits",
      order = "id asc"
    },
    {
      "reports",
      has_many = "PostReports",
      oreder = "id desc"
    },
    {
      "votes",
      has_many = "Votes",
      key = "object_id",
      where = {
        object_type = 1
      }
    },
    {
      "moderation_log",
      belongs_to = "ModerationLogs"
    },
    {
      "posts_search",
      has_one = "PostsSearch"
    },
    {
      "immediate_children",
      has_many = "Posts",
      order = "post_number asc",
      key = {
        parent_post_id = "id"
      }
    },
    {
      "has_children",
      fetch = function(self)
        local res = db.query("select 1 from " .. tostring(db.escape_identifier(self.__class:table_name())) .. " where parent_post_id = ? limit 1", self.id)
        if next(res) then
          return true
        else
          return false
        end
      end,
      preload = function(posts, _, _, name)
        local encode_value_list
        encode_value_list = require("community.helpers.models").encode_value_list
        local tbl_name = db.escape_identifier(self.__class:table_name())
        local id_list = encode_value_list((function()
          local _accum_0 = { }
          local _len_0 = 1
          for _index_0 = 1, #posts do
            local p = posts[_index_0]
            _accum_0[_len_0] = {
              p.id
            }
            _len_0 = _len_0 + 1
          end
          return _accum_0
        end)())
        local res = db.query("select pid.id, exists(select 1 from " .. tostring(tbl_name) .. " pc where pc.parent_post_id = pid.id limit 1) as has_children from (" .. tostring(id_list) .. ") pid (id)")
        local by_id
        do
          local _tbl_0 = { }
          for _index_0 = 1, #res do
            local r = res[_index_0]
            _tbl_0[r.id] = r.has_children
          end
          by_id = _tbl_0
        end
        for _index_0 = 1, #posts do
          local post = posts[_index_0]
          post[name] = by_id[post.id] or false
        end
      end
    },
    {
      "has_next_post",
      fetch = function(self)
        local clause = db.encode_clause({
          topic_id = self.topic_id,
          parent_post_id = self.parent_post_id or db.NULL,
          depth = self.depth
        })
        return not not unpack(Posts:select("\n          where " .. tostring(clause) .. " and post_number > ?\n          limit 1\n        ", self.post_number, {
          fields = "1"
        }))
      end,
      preload = function(posts, _, _, name)
        local encode_value_list
        encode_value_list = require("community.helpers.models").encode_value_list
        local tbl_name = db.escape_identifier(self.__class:table_name())
        local id_list = encode_value_list((function()
          local _accum_0 = { }
          local _len_0 = 1
          for _index_0 = 1, #posts do
            local p = posts[_index_0]
            _accum_0[_len_0] = {
              p.id,
              p.topic_id,
              p.parent_post_id or db.NULL,
              p.depth,
              p.post_number
            }
            _len_0 = _len_0 + 1
          end
          return _accum_0
        end)())
        local res = db.query("select tuple.id, exists(\n          select 1 from " .. tostring(tbl_name) .. " pc\n            where pc.topic_id = tuple.topic_id\n              and pc.parent_post_id is not distinct from tuple.parent_post_id::integer\n              and pc.depth = tuple.depth\n              and pc.post_number > tuple.post_number\n            limit 1\n        ) as has_next_post from (" .. tostring(id_list) .. ") tuple (id, topic_id, parent_post_id, depth, post_number)")
        local by_id
        do
          local _tbl_0 = { }
          for _index_0 = 1, #res do
            local r = res[_index_0]
            _tbl_0[r.id] = r.has_next_post
          end
          by_id = _tbl_0
        end
        for _index_0 = 1, #posts do
          local post = posts[_index_0]
          post[name] = by_id[post.id] or false
        end
      end
    },
    {
      "body_html",
      fetch = function(self)
        local _exp_0 = self.body_format
        if self.__class.body_formats.html == _exp_0 then
          return self.body
        elseif self.__class.body_formats.markdown == _exp_0 then
          local markdown_to_html
          markdown_to_html = require("community.helpers.markdown").markdown_to_html
          return markdown_to_html(self.body)
        end
      end
    }
  }
  self.statuses = enum({
    default = 1,
    archived = 2,
    spam = 3
  })
  self.body_formats = enum({
    html = 1,
    markdown = 2
  })
  self.filter_body = function(self, body, format)
    if format == nil then
      format = self.body_formats.html
    end
    format = self.body_formats:for_db(format)
    if not (type(body) == "string") then
      return nil, "body must be provided"
    end
    local is_empty_html
    is_empty_html = require("community.helpers.html").is_empty_html
    local html
    local _exp_0 = format
    if self.body_formats.html == _exp_0 then
      html = body
    elseif self.body_formats.markdown == _exp_0 then
      local markdown_to_html
      markdown_to_html = require("community.helpers.markdown").markdown_to_html
      local out = markdown_to_html(body)
      if not (out) then
        return nil, "invalid markdown"
      end
      html = out
    end
    if is_empty_html(html) then
      return nil, "body must be provided"
    end
    return body
  end
  self.create = function(self, opts, ...)
    if opts == nil then
      opts = { }
    end
    assert(opts.topic_id, "missing topic id")
    assert(opts.user_id, "missing user id")
    assert(opts.body, "missing body")
    do
      local parent = opts.parent_post
      if parent then
        assert(parent.topic_id == opts.topic_id, "invalid parent (" .. tostring(parent.topic_id) .. " != " .. tostring(opts.topic_id) .. ")")
        opts.parent_post_id = parent.id
        opts.parent_post = nil
      end
    end
    if opts.parent_post_id then
      opts.depth = db.raw(db.interpolate_query("(select depth + 1 from " .. tostring(db.escape_identifier(self:table_name())) .. " where id = ?)", opts.parent_post_id))
    else
      opts.depth = 1
    end
    local number_cond = {
      topic_id = opts.topic_id,
      depth = opts.depth,
      parent_post_id = opts.parent_post_id or db.NULL
    }
    local post_number = db.interpolate_query("\n     (select coalesce(max(post_number), 0) from " .. tostring(db.escape_identifier(self:table_name())) .. "\n       where " .. tostring(db.encode_clause(number_cond)) .. ") + 1")
    opts.status = opts.status and self.statuses:for_db(opts.status)
    opts.post_number = db.raw(post_number)
    if opts.body_format then
      opts.body_format = self.body_formats:for_db(opts.body_format)
    end
    return _class_0.__parent.create(self, opts, ... or {
      returning = {
        "status"
      }
    })
  end
  self.preload_mentioned_users = function(self, posts)
    local CommunityUsers
    CommunityUsers = require("community.models").CommunityUsers
    local all_usernames = { }
    local usernames_by_post = { }
    for _index_0 = 1, #posts do
      local post = posts[_index_0]
      local usernames = self:_parse_usernames(post.body)
      if next(usernames) then
        usernames_by_post[post.id] = usernames
        for _index_1 = 1, #usernames do
          local u = usernames[_index_1]
          table.insert(all_usernames, u)
        end
      end
    end
    local users = CommunityUsers:find_users_by_name(all_usernames)
    local users_by_username
    do
      local _tbl_0 = { }
      for _index_0 = 1, #users do
        local u = users[_index_0]
        _tbl_0[u.username] = u
      end
      users_by_username = _tbl_0
    end
    for _index_0 = 1, #posts do
      local post = posts[_index_0]
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = usernames_by_post[post.id] or { }
        for _index_1 = 1, #_list_0 do
          local _continue_0 = false
          repeat
            local uname = _list_0[_index_1]
            if not (users_by_username[uname]) then
              _continue_0 = true
              break
            end
            local _value_0 = users_by_username[uname]
            _accum_0[_len_0] = _value_0
            _len_0 = _len_0 + 1
            _continue_0 = true
          until true
          if not _continue_0 then
            break
          end
        end
        post.mentioned_users = _accum_0
      end
    end
    return posts
  end
  self._parse_usernames = function(self, body)
    local _accum_0 = { }
    local _len_0 = 1
    for username in body:gmatch("@([%w-_]+)") do
      _accum_0[_len_0] = username
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end
  local _ = false
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Posts = _class_0
  return _class_0
end
