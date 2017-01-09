local db = require("lapis.db")
local Model
Model = require("community.model").Model
local slugify
slugify = require("lapis.util").slugify
local memoize1
memoize1 = require("community.helpers.models").memoize1
local enum
enum = require("lapis.db.model").enum
local Topics
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
    allowed_to_post = function(self, user)
      if not (user) then
        return false
      end
      if self.deleted then
        return false
      end
      if self.locked then
        return false
      end
      if not (self:is_default()) then
        return false
      end
      return self:allowed_to_view(user)
    end,
    allowed_to_view = memoize1(function(self, user)
      if self.deleted then
        return false
      end
      local can_view
      if self.category_id then
        can_view = self:get_category():allowed_to_view(user)
      else
        can_view = true
      end
      if can_view then
        if self:get_ban(user) then
          return false
        end
      end
      return can_view
    end),
    allowed_to_edit = memoize1(function(self, user)
      if self.deleted then
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
      if self:allowed_to_moderate(user) then
        return true
      end
      return false
    end),
    allowed_to_moderate = memoize1(function(self, user)
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
    end),
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
      self:update({
        posts_count = not is_moderation_log and db.raw("posts_count + 1") or nil,
        root_posts_count = (function()
          if post.depth == 1 then
            return db.raw("root_posts_count + 1")
          end
        end)(),
        last_post_id = not is_moderation_log and post.id or nil,
        category_order = category_order
      }, {
        timestamp = false
      })
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
      if not (_class_0.__parent.delete(self)) then
        return false
      end
      local _list_0 = self:get_posts()
      for _index_0 = 1, #_list_0 do
        local post = _list_0[_index_0]
        post:hard_delete()
      end
      local PendingPosts, TopicParticipants, UserTopicLastSeens, CategoryPostLogs, CommunityUsers
      do
        local _obj_0 = require("community.models")
        PendingPosts, TopicParticipants, UserTopicLastSeens, CategoryPostLogs, CommunityUsers = _obj_0.PendingPosts, _obj_0.TopicParticipants, _obj_0.UserTopicLastSeens, _obj_0.CategoryPostLogs, _obj_0.CommunityUsers
      end
      CategoryPostLogs:clear_posts_for_topic(self)
      if self.user_id then
        CommunityUsers:for_user(self:get_user()):increment("topics_count", -1)
      end
      do
        local category = self:get_category()
        if category then
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
          topic_id = self.id
        })
      end
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
          CommunityUsers:for_user(self:get_user()):increment("topics_count", -1)
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
      self.user_bans = self.user_bans or { }
      local ban = self.user_bans[user.id]
      if ban ~= nil then
        return ban
      end
      self.user_bans[user.id] = self:find_ban(user) or false
      return self.user_bans[user.id]
    end,
    find_ban = function(self, user)
      if not (user) then
        return nil
      end
      local Bans
      Bans = require("community.models").Bans
      return Bans:find_for_object(self, user)
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
          return {
            down = true,
            up = true
          }
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
        return 
      end
      if not (self.user_topic_last_seen) then
        return 
      end
      if not (self.last_post_id) then
        return 
      end
      assert(self.user_topic_last_seen.user_id == user.id, "unexpected user for last seen")
      return self.user_topic_last_seen.post_id < self.last_post_id
    end,
    notification_target_users = function(self)
      local Subscriptions
      Subscriptions = require("community.models").Subscriptions
      local subs = self:get_subscriptions()
      Subscriptions:preload_relations(subs, "user")
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
    renumber_posts = function(self, parent_post)
      local Posts
      Posts = require("community.models").Posts
      local cond
      if parent_post then
        assert(parent_post.topic_id == self.id, "expecting")
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
      return db.query("\n      update " .. tostring(tbl) .. " as posts set post_number = new_number from (\n        select id, row_number() over () as new_number\n        from " .. tostring(tbl) .. "\n        where " .. tostring(db.encode_clause(cond)) .. "\n        order by post_number asc\n      ) foo\n      where posts.id = foo.id and posts.post_number != new_number\n    ")
    end,
    post_needs_approval = function(self)
      local category = self:get_category()
      if not (category) then
        return false
      end
      local Categories
      Categories = require("community.models").Categories
      return category:get_approval_type() == Categories.approval_types.pending
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
    archive = function(self)
      if not (self.status) then
        self:refresh("status")
      end
      if not (self.status == self.__class.statuses.default) then
        return nil
      end
      self:set_status("archived")
      return true
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
    get_bookmark = memoize1(function(self, user)
      local Bookmarks
      Bookmarks = require("community.models").Bookmarks
      return Bookmarks:get(self, user)
    end),
    find_subscription = function(self, user)
      local Subscriptions
      Subscriptions = require("community.models").Subscriptions
      return Subscriptions:find_subscription(self, user)
    end,
    is_subscribed = memoize1(function(self, user)
      local Subscriptions
      Subscriptions = require("community.models").Subscriptions
      if not (user) then
        return 
      end
      return Subscriptions:is_subscribed(self, user, user.id == self.user_id)
    end),
    subscribe = function(self, user)
      if not (self:allowed_to_view(user)) then
        return 
      end
      if not (user) then
        return 
      end
      local Subscriptions
      Subscriptions = require("community.models").Subscriptions
      return Subscriptions:subscribe(self, user, user.id == self.user_id)
    end,
    unsubscribe = function(self, user)
      if not (user) then
        return 
      end
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
    end
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
    }
  }
  self.statuses = enum({
    default = 1,
    archived = 2,
    spam = 2
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
    return Model.create(self, opts, {
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
  self.recount = function(self, where)
    local Posts
    Posts = require("community.models").Posts
    return db.update(self:table_name(), {
      root_posts_count = db.raw("\n        (select count(*) from " .. tostring(db.escape_identifier(Posts:table_name())) .. "\n          where topic_id = " .. tostring(db.escape_identifier(self:table_name())) .. ".id\n          and depth = 1)\n      "),
      posts_count = db.raw("\n        (select count(*) from " .. tostring(db.escape_identifier(Posts:table_name())) .. "\n          where topic_id = " .. tostring(db.escape_identifier(self:table_name())) .. ".id and\n            not deleted and\n            moderation_log_id is null)\n      ")
    }, where)
  end
  self.preload_bans = function(self, topics, user)
    if not (user) then
      return 
    end
    if not (next(topics)) then
      return 
    end
    local Bans
    Bans = require("community.models").Bans
    local bans = Bans:select("\n      where banned_user_id = ? and object_type = ? and object_id in ?\n    ", user.id, Bans.object_types.topic, db.list((function()
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #topics do
        local t = topics[_index_0]
        _accum_0[_len_0] = t.id
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end)()))
    local bans_by_topic_id
    do
      local _tbl_0 = { }
      for _index_0 = 1, #bans do
        local b = bans[_index_0]
        _tbl_0[b.object_id] = b
      end
      bans_by_topic_id = _tbl_0
    end
    for _index_0 = 1, #topics do
      local t = topics[_index_0]
      t.user_bans = t.user_bans or { }
      t.user_bans[user.id] = bans_by_topic_id[t.id] or false
    end
    return true
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Topics = _class_0
  return _class_0
end
