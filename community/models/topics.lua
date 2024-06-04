local db = require("lapis.db")
local Model, VirtualModel
do
  local _obj_0 = require("community.model")
  Model, VirtualModel = _obj_0.Model, _obj_0.VirtualModel
end
local slugify
slugify = require("lapis.util").slugify
local enum
enum = require("lapis.db.model").enum
local preload
preload = require("lapis.db.model").preload
local VOTE_TYPES_DEFAULT = {
  down = true,
  up = true
}
local Topics
do
  local _class_0
  local TopicViewers
  local _parent_0 = Model
  local _base_0 = {
    with_user = VirtualModel:make_loader("topic_viewers", function(self, user_id)
      assert(user_id, "expecting user id")
      return TopicViewers:load({
        user_id = user_id,
        topic_id = self.id
      })
    end),
    allowed_to_post = function(self, user, req)
      if not (user) then
        return false
      end
      if self.deleted then
        return false
      end
      if self.locked then
        return false
      end
      if not (self:is_default() or self:is_hidden()) then
        return false
      end
      return self:allowed_to_view(user, req)
    end,
    allowed_to_view = function(self, user, req)
      if self.deleted then
        return false
      end
      if self.category_id then
        if not (self:get_category():allowed_to_view(user, req)) then
          return false
        end
      end
      if self:get_ban(user) then
        return false
      end
      return true
    end,
    allowed_to_edit = function(self, user)
      if self.deleted then
        return false
      end
      if not (user) then
        return false
      end
      if user:is_admin() then
        return true
      end
      if self:is_protected() then
        return false
      end
      if self:is_archived() then
        return false
      end
      if user.id == self.user_id then
        return true
      end
      if self:allowed_to_moderate(user) then
        return true
      end
      return false
    end,
    allowed_to_moderate = function(self, user)
      if self.deleted then
        return false
      end
      if not (user) then
        return false
      end
      if user:is_admin() then
        return true
      end
      if not (self.category_id) then
        return false
      end
      local Categories
      Categories = require("community.models").Categories
      return self:get_category():allowed_to_moderate(user)
    end,
    increment_participant = function(self, user)
      if not (user) then
        return 
      end
      local TopicParticipants
      TopicParticipants = require("community.models").TopicParticipants
      return TopicParticipants:increment(self.id, user.id)
    end,
    decrement_participant = function(self, user)
      if not (user) then
        return 
      end
      local TopicParticipants
      TopicParticipants = require("community.models").TopicParticipants
      return TopicParticipants:decrement(self.id, user.id)
    end,
    increment_from_post = function(self, post, opts)
      assert(post.topic_id == self.id, "invalid post sent to topic")
      local is_moderation_log = post:is_moderation_event()
      local category_order
      if not (is_moderation_log or (opts and opts.update_category_order == false)) then
        local Categories
        Categories = require("community.models").Categories
        local category = self:get_category()
        if category and category:order_by_date() then
          category_order = Topics:update_category_order_sql(self.category_id)
        end
      end
      local posts_count
      if not is_moderation_log then
        posts_count = db.raw("posts_count + 1")
      end
      local root_posts_count
      if post.depth == 1 then
        root_posts_count = db.raw("root_posts_count + 1")
      end
      self:update({
        posts_count = posts_count,
        root_posts_count = root_posts_count,
        last_post_id = not is_moderation_log and post.id or nil,
        category_order = category_order
      }, {
        timestamp = false
      })
      if posts_count then
        self:on_increment_callback("posts_count", 1)
      end
      if root_posts_count then
        self:on_increment_callback("root_posts_count", 1)
      end
      do
        local category = self:get_category()
        if category then
          return category:increment_from_post(post)
        end
      end
    end,
    refresh_last_post = function(self)
      local Posts
      Posts = require("community.models").Posts
      return self:update({
        last_post_id = db.raw(db.interpolate_query("(\n        select id from " .. tostring(db.escape_identifier(Posts:table_name())) .. "\n        where\n          topic_id = ? and\n            not deleted and\n            status = ? and\n            moderation_log_id is null and\n            (depth != 1 or post_number != 1)\n        order by id desc\n        limit 1\n      )", self.id, self.__class.statuses.default))
      }, {
        timestamp = false
      })
    end,
    delete = function(self, force)
      if force == "hard" then
        return self:hard_delete()
      else
        return self:soft_delete()
      end
    end,
    hard_delete = function(self)
      local deleted, res = Model.delete(self, db.raw("*"))
      if not (deleted) then
        return false
      end
      local deleted_topic = unpack(res)
      local was_soft_deleted = deleted_topic.deleted
      local _list_0 = self:get_posts()
      for _index_0 = 1, #_list_0 do
        local post = _list_0[_index_0]
        post:hard_delete(deleted_topic)
      end
      local PendingPosts, TopicParticipants, UserTopicLastSeens, CategoryPostLogs, CommunityUsers, Bans, Subscriptions, Bookmarks
      do
        local _obj_0 = require("community.models")
        PendingPosts, TopicParticipants, UserTopicLastSeens, CategoryPostLogs, CommunityUsers, Bans, Subscriptions, Bookmarks = _obj_0.PendingPosts, _obj_0.TopicParticipants, _obj_0.UserTopicLastSeens, _obj_0.CategoryPostLogs, _obj_0.CommunityUsers, _obj_0.Bans, _obj_0.Subscriptions, _obj_0.Bookmarks
      end
      CategoryPostLogs:clear_posts_for_topic(self)
      if not was_soft_deleted and self.user_id then
        CommunityUsers:increment(self.user_id, "topics_count", -1)
      end
      do
        local category = self:get_category()
        if category then
          local restore_deleted_count
          if was_soft_deleted then
            restore_deleted_count = db.raw("deleted_topics_count - 1")
          end
          category:update({
            topics_count = db.raw("topics_count - 1"),
            deleted_topics_count = restore_deleted_count
          }, {
            timestamp = false
          })
          if category.last_topic_id == self.id then
            category:refresh_last_topic()
          end
        end
      end
      local _list_1 = {
        PendingPosts,
        TopicParticipants,
        UserTopicLastSeens
      }
      for _index_0 = 1, #_list_1 do
        local model = _list_1[_index_0]
        db.delete(model:table_name(), {
          topic_id = assert(self.id)
        })
      end
      local _list_2 = {
        Bans,
        Subscriptions,
        Bookmarks
      }
      for _index_0 = 1, #_list_2 do
        local model = _list_2[_index_0]
        db.delete(model:table_name(), db.clause({
          object_type = assert(model:object_type_for_object(self)),
          object_id = assert(self.id)
        }))
      end
      do
        local poll = self:get_poll()
        if poll then
          poll:delete()
        end
      end
      return true
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
        local CommunityUsers, Categories, CategoryPostLogs
        do
          local _obj_0 = require("community.models")
          CommunityUsers, Categories, CategoryPostLogs = _obj_0.CommunityUsers, _obj_0.Categories, _obj_0.CategoryPostLogs
        end
        CategoryPostLogs:clear_posts_for_topic(self)
        if self.user_id then
          CommunityUsers:increment(self.user_id, "topics_count", -1)
        end
        do
          local category = self:get_category()
          if category then
            category:update({
              deleted_topics_count = db.raw("deleted_topics_count + 1")
            }, {
              timestamp = false
            })
            if category.last_topic_id == self.id then
              category:refresh_last_topic()
            end
          end
        end
        return true
      end
      return false
    end,
    get_ban = function(self, user)
      if not (user) then
        return nil
      end
      return self:with_user(user.id):get_ban()
    end,
    find_recent_log = function(self, action)
      local ModerationLogs
      ModerationLogs = require("community.models").ModerationLogs
      return unpack(ModerationLogs:select("\n      where object_type = ? and object_id = ? and action = ?\n      order by id desc\n      limit 1\n    ", ModerationLogs.object_types.topic, self.id, action))
    end,
    get_lock_log = function(self)
      if not (self.locked) then
        return 
      end
      if not (self.lock_log) then
        self.lock_log = self:find_recent_log("topic.lock")
      end
      return self.lock_log
    end,
    get_sticky_log = function(self)
      if not (self.sticky) then
        return 
      end
      if not (self.sticky_log) then
        local ModerationLogs
        ModerationLogs = require("community.models").ModerationLogs
        self.sticky_log = self:find_recent_log("topic.stick")
      end
      return self.sticky_log
    end,
    available_vote_types = function(self, post)
      do
        local category = self:get_category()
        if category then
          return category:available_vote_types(post)
        else
          return VOTE_TYPES_DEFAULT
        end
      end
    end,
    set_seen = function(self, user)
      if not (user) then
        return 
      end
      if not (self.last_post_id) then
        return 
      end
      local insert_on_conflict_update
      insert_on_conflict_update = require("community.helpers.models").insert_on_conflict_update
      local UserTopicLastSeens
      UserTopicLastSeens = require("community.models").UserTopicLastSeens
      return insert_on_conflict_update(UserTopicLastSeens, {
        user_id = user.id,
        topic_id = self.id
      }, {
        post_id = self.last_post_id
      })
    end,
    has_unread = function(self, user)
      if not (user) then
        return false
      end
      if not (self.last_post_id) then
        return false
      end
      do
        local last_seen = self:with_user(user.id):get_last_seen()
        if last_seen then
          return last_seen.post_id < self.last_post_id
        else
          return false
        end
      end
    end,
    notification_target_users = function(self)
      local Subscriptions
      Subscriptions = require("community.models").Subscriptions
      local subs = self:get_subscriptions()
      preload(subs, "user")
      local include_owner = true
      local targets
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #subs do
          local _continue_0 = false
          repeat
            local sub = subs[_index_0]
            if sub.user_id == self.user_id then
              include_owner = false
            end
            if not (sub.subscribed) then
              _continue_0 = true
              break
            end
            local _value_0 = sub:get_user()
            _accum_0[_len_0] = _value_0
            _len_0 = _len_0 + 1
            _continue_0 = true
          until true
          if not _continue_0 then
            break
          end
        end
        targets = _accum_0
      end
      if include_owner then
        table.insert(targets, self:get_user())
      end
      return targets
    end,
    find_latest_root_post = function(self)
      local Posts
      Posts = require("community.models").Posts
      return unpack(Posts:select("\n      where topic_id = ? and depth = 1 order by post_number desc limit 1\n    ", self.id))
    end,
    reposition_post = function(self, post, position)
      assert(post.topic_id == self.id, "post is not in topic")
      assert(position, "missing position")
      local Posts
      Posts = require("community.models").Posts
      local tbl = db.escape_identifier(Posts:table_name())
      local cond = {
        parent_post_id = post.parent_post_id or db.NULL,
        topic_id = self.id,
        depth = post.depth
      }
      local order_number
      if position < post.post_number then
        order_number = position - 0.5
      else
        order_number = position + 0.5
      end
      return db.query("\n      update " .. tostring(tbl) .. " as posts set post_number = new_number\n      from (\n        select id, row_number() over (\n          order by (case " .. tostring(tbl) .. ".id\n            when ? then ?\n            else " .. tostring(tbl) .. ".post_number\n          end) asc\n        ) as new_number\n        from " .. tostring(tbl) .. "\n        where " .. tostring(db.encode_clause(cond)) .. "\n      ) foo\n      where posts.id = foo.id and posts.post_number != new_number\n    ", post.id, order_number)
    end,
    renumber_posts = function(self, parent_post, field)
      if field == nil then
        field = "post_number"
      end
      local Posts
      Posts = require("community.models").Posts
      local cond
      if parent_post then
        assert(parent_post.topic_id == self.id, "parent post is not in the correct topic")
        cond = {
          parent_post_id = parent_post.id
        }
      else
        cond = {
          topic_id = self.id,
          parent_post_id = db.NULL,
          depth = 1
        }
      end
      local tbl = db.escape_identifier(Posts:table_name())
      local order = "order by " .. tostring(db.escape_identifier(field)) .. " asc"
      return db.query("\n      update " .. tostring(tbl) .. " as posts set post_number = new_number from (\n        select id, row_number() over (" .. tostring(order) .. ") as new_number\n        from " .. tostring(tbl) .. "\n        where " .. tostring(db.encode_clause(cond)) .. "\n        " .. tostring(order) .. "\n      ) foo\n      where posts.id = foo.id and posts.post_number != new_number\n    ")
    end,
    post_needs_approval = function(self, user, post_params)
      if self:allowed_to_moderate(user) then
        return false
      end
      local Categories, CommunityUsers
      do
        local _obj_0 = require("community.models")
        Categories, CommunityUsers = _obj_0.Categories, _obj_0.CommunityUsers
      end
      do
        local category = self:get_category()
        if category then
          if category:get_approval_type() == Categories.approval_types.pending then
            return true
          end
        end
      end
      do
        local cu = CommunityUsers:for_user(user)
        if cu then
          local needs_approval, warning = cu:needs_approval_to_post()
          if needs_approval then
            return true, warning
          end
        end
      end
      return false
    end,
    get_root_order_ranges = function(self, status)
      if status == nil then
        status = "default"
      end
      local Posts
      Posts = require("community.models").Posts
      status = Posts.statuses:for_db(status)
      local res = db.query("\n      select min(post_number), max(post_number)\n      from " .. tostring(db.escape_identifier(Posts:table_name())) .. "\n      where topic_id = ? and depth = 1 and parent_post_id is null and status = ?\n    ", self.id, status)
      do
        res = unpack(res)
        if res then
          return res.min, res.max
        end
      end
    end,
    is_archived = function(self)
      return self.status == self.__class.statuses.archived or (self:get_category() and self:get_category().archived)
    end,
    is_hidden = function(self)
      return self.status == self.__class.statuses.hidden
    end,
    is_protected = function(self)
      return self.protected
    end,
    is_default = function(self)
      return self.status == self.__class.statuses.default and not self:is_archived()
    end,
    set_status = function(self, status)
      self:update({
        status = self.__class.statuses:for_db(status)
      })
      local CategoryPostLogs
      CategoryPostLogs = require("community.models").CategoryPostLogs
      if self.status == self.__class.statuses.default then
        CategoryPostLogs:log_topic_posts(self)
      else
        CategoryPostLogs:clear_posts_for_topic(self)
      end
      local category = self:get_category()
      if category and category.last_topic_id == self.id then
        return category:refresh_last_topic()
      end
    end,
    hide = function(self)
      if not (self.status) then
        self:refresh("status")
      end
      local _exp_0 = self.status
      if self.__class.statuses.default == _exp_0 then
        self:set_status("hidden")
        return true
      else
        return nil, "can't hide from status: " .. tostring(self.__class.statuses:to_name(self.status))
      end
    end,
    archive = function(self)
      if not (self.status) then
        self:refresh("status")
      end
      local _exp_0 = self.status
      if self.__class.statuses.default == _exp_0 or self.__class.statuses.hidden == _exp_0 then
        self:set_status("archived")
        return true
      else
        return nil, "can't archive from status: " .. tostring(self.__class.statuses:to_name(self.status))
      end
    end,
    get_tags = function(self)
      if not (self.tags) then
        return 
      end
      local category = self:get_category()
      if not (category) then
        return self.tags
      end
      local tags_by_slug
      do
        local _tbl_0 = { }
        local _list_0 = category:get_tags()
        for _index_0 = 1, #_list_0 do
          local t = _list_0[_index_0]
          _tbl_0[t.slug] = t
        end
        tags_by_slug = _tbl_0
      end
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = self.tags
      for _index_0 = 1, #_list_0 do
        local t = _list_0[_index_0]
        _accum_0[_len_0] = tags_by_slug[t]
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end,
    get_bookmark = function(self, user)
      return self:with_user(user.id):get_bookmark()
    end,
    find_subscription = function(self, user)
      return self:with_user(user.id):get_subscription()
    end,
    is_subscribed = function(self, user)
      local default_subscribed = user.id == self.user_id
      do
        local sub = self:find_subscription(user)
        if sub then
          return sub:is_subscribed()
        else
          return default_subscribed
        end
      end
    end,
    subscribe = function(self, user, req)
      local Subscriptions
      Subscriptions = require("community.models").Subscriptions
      return Subscriptions:subscribe(self, user, user.id == self.user_id)
    end,
    unsubscribe = function(self, user)
      local Subscriptions
      Subscriptions = require("community.models").Subscriptions
      return Subscriptions:unsubscribe(self, user, user.id == self.user_id)
    end,
    can_move_to = function(self, user, target_category)
      if not (target_category) then
        return nil, "missing category"
      end
      if target_category.id == self.category_id then
        return nil, "can't move to same category"
      end
      local parent = self:movable_parent_category(user)
      local valid_children
      do
        local _tbl_0 = { }
        local _list_0 = parent:get_flat_children()
        for _index_0 = 1, #_list_0 do
          local c = _list_0[_index_0]
          _tbl_0[c.id] = true
        end
        valid_children = _tbl_0
      end
      valid_children[parent.id] = true
      if not (valid_children[target_category.id]) then
        return nil, "invalid parent category"
      end
      return true
    end,
    movable_parent_category = function(self, user)
      local category = self:get_category()
      if not (category) then
        return nil, "no category"
      end
      local ancestors = category:get_ancestors()
      for i = #ancestors, 1, -1 do
        local a = ancestors[i]
        if a:allowed_to_moderate(user) then
          return a
        end
      end
      return category
    end,
    move_to_category = function(self, new_category)
      assert(new_category, "missing category")
      if not (self.category_id) then
        return nil, "can't move topic that isn't part of category"
      end
      if new_category.directory then
        return nil, "can't move to directory"
      end
      if self.deleted then
        return nil, "can't move deleted topic"
      end
      local old_category = self:get_category()
      local Posts, CategoryPostLogs, ModerationLogs, PendingPosts, PostReports
      do
        local _obj_0 = require("community.models")
        Posts, CategoryPostLogs, ModerationLogs, PendingPosts, PostReports = _obj_0.Posts, _obj_0.CategoryPostLogs, _obj_0.ModerationLogs, _obj_0.PendingPosts, _obj_0.PostReports
      end
      CategoryPostLogs:clear_posts_for_topic(self)
      self:update({
        category_id = new_category.id
      })
      self:clear_loaded_relation("category")
      new_category:refresh_last_topic()
      old_category:refresh_last_topic()
      db.update(ModerationLogs:table_name(), {
        category_id = new_category.id
      }, {
        object_type = ModerationLogs.object_types.topic,
        object_id = self.id,
        category_id = old_category.id
      })
      local topic_posts = db.list({
        db.raw(db.interpolate_query("\n        select id from " .. tostring(db.escape_identifier(Posts:table_name())) .. "\n        where topic_id = ?\n      ", self.id))
      })
      db.update(PostReports:table_name(), {
        category_id = new_category.id
      }, {
        category_id = old_category.id,
        post_id = topic_posts
      })
      db.update(PendingPosts:table_name(), {
        category_id = new_category.id
      }, {
        topic_id = self.id,
        category_id = old_category.id
      })
      CategoryPostLogs:log_topic_posts(self)
      old_category:update({
        topics_count = db.raw("topics_count - 1")
      }, {
        timestamp = false
      })
      new_category:update({
        topics_count = db.raw("topics_count + 1")
      }, {
        timestamp = false
      })
      return true
    end,
    get_score = function(self)
      local post = self:get_topic_post()
      if not (post) then
        return 0
      end
      return post.up_votes_count - post.down_votes_count
    end,
    calculate_score_category_order = function(self)
      local adjust = self.rank_adjustment or 0
      return self.__class:calculate_score_category_order(self:get_score() + adjust, self.created_at, self:get_category():topic_score_bucket_size())
    end,
    update_rank_adjustment = function(self, amount)
      local category = self:get_category()
      if not (category) then
        return nil, "no category"
      end
      if not (category:order_by_score()) then
        return nil, "category not ranked by score"
      end
      self.rank_adjustment = amount or 0
      return self:update({
        rank_adjustment = amount,
        category_order = self:calculate_score_category_order()
      })
    end,
    increment_counter = function(self, field, amount)
      local res = self:update({
        [field] = db.raw(db.interpolate_query(tostring(db.escape_identifier(field)) .. " + ?", amount))
      }, {
        timestamp = false
      })
      self:on_increment_callback(field, amount)
      return res
    end,
    on_increment_callback = function(self, field, amount) end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "Topics",
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
    local _base_1 = { }
    _base_1.__index = _base_1
    setmetatable(_base_1, _parent_1.__base)
    _class_1 = setmetatable({
      __init = function(self, ...)
        return _class_1.__parent.__init(self, ...)
      end,
      __base = _base_1,
      __name = "TopicViewers",
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
      "topic_id",
      "user_id"
    }
    self.relations = {
      {
        "subscription",
        has_one = "Subscriptions",
        key = {
          user_id = "user_id",
          object_id = "topic_id"
        },
        where = {
          object_type = 1
        }
      },
      {
        "bookmark",
        has_one = "Bookmarks",
        key = {
          user_id = "user_id",
          object_id = "topic_id"
        },
        where = {
          object_type = 2
        }
      },
      {
        "last_seen",
        has_one = "UserTopicLastSeens",
        key = {
          "user_id",
          "topic_id"
        }
      },
      {
        "ban",
        has_one = "Bans",
        key = {
          banned_user_id = "user_id",
          object_id = "topic_id"
        },
        where = {
          object_type = 2
        }
      }
    }
    if _parent_1.__inherited then
      _parent_1.__inherited(_parent_1, _class_1)
    end
    TopicViewers = _class_1
  end
  self.relations = {
    {
      "category",
      belongs_to = "Categories"
    },
    {
      "user",
      belongs_to = "Users"
    },
    {
      "posts",
      has_many = "Posts"
    },
    {
      "topic_post",
      has_one = "Posts",
      key = "topic_id",
      where = {
        parent_post_id = db.NULL,
        post_number = 1,
        depth = 1
      }
    },
    {
      "last_post",
      belongs_to = "Posts"
    },
    {
      "subscriptions",
      has_many = "Subscriptions",
      key = "object_id",
      where = {
        object_type = 1
      }
    },
    {
      "moderation_logs",
      has_many = "ModerationLogs",
      key = "object_id",
      where = {
        object_type = 1
      }
    },
    {
      "poll",
      has_one = "TopicPolls"
    }
  }
  self.statuses = enum({
    default = 1,
    archived = 2,
    spam = 3,
    hidden = 4
  })
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    if opts.title then
      opts.slug = opts.slug or slugify(opts.title)
    end
    opts.status = opts.status and self.statuses:for_db(opts.status)
    opts.category_order = opts.category_order or self:update_category_order_sql(opts.category_id)
    if opts.data then
      local db_json
      db_json = require("community.helpers.models").db_json
      opts.data = db_json(opts.data)
    end
    return _class_0.__parent.create(self, opts, {
      returning = {
        "status"
      }
    })
  end
  self.update_category_order_sql = function(self, category_id)
    if not (category_id) then
      return nil
    end
    return db.raw(db.interpolate_query("\n      (select coalesce(max(category_order), 0) + 1\n      from " .. tostring(db.escape_identifier(self:table_name())) .. "\n      where category_id = ?)\n    ", category_id))
  end
  self.calculate_score_category_order = function(self, score, created_at, time_bucket)
    local Categories
    Categories = require("community.models").Categories
    local start = Categories.score_starting_date
    local date = require("date")
    local e = date.epoch()
    local time_score = (date.diff(date(created_at), e):spanseconds() - start) / time_bucket
    local adjusted_score = 2 * math.log10(math.max(1, math.abs(score) + 1))
    if not (score > 0) then
      adjusted_score = -adjusted_score
    end
    return math.floor((time_score + adjusted_score) * 1000)
  end
  self.recount = function(self, ...)
    local Posts
    Posts = require("community.models").Posts
    local id_field = tostring(db.escape_identifier(self:table_name())) .. ".id"
    return db.update(self:table_name(), {
      root_posts_count = db.raw("\n        (select count(*) from " .. tostring(db.escape_identifier(Posts:table_name())) .. "\n          where topic_id = " .. tostring(id_field) .. "\n          and depth = 1)\n      "),
      deleted_posts_count = db.raw("\n        (select count(*) from " .. tostring(db.escape_identifier(Posts:table_name())) .. "\n          where topic_id = " .. tostring(id_field) .. " and\n            deleted and\n            moderation_log_id is null)\n      "),
      posts_count = db.raw("\n        (select count(*) from " .. tostring(db.escape_identifier(Posts:table_name())) .. "\n          where topic_id = " .. tostring(id_field) .. " and\n            not deleted and\n            moderation_log_id is null)\n      ")
    }, ...)
  end
  self.preload_bans = function(self, topics, user)
    if not (user) then
      return 
    end
    if not (next(topics)) then
      return 
    end
    preload((function()
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #topics do
        local t = topics[_index_0]
        _accum_0[_len_0] = t:with_user(user.id)
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end)(), "ban")
    return true
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Topics = _class_0
  return _class_0
end
