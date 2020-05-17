local db = require("lapis.db")
local enum
enum = require("lapis.db.model").enum
local Model
Model = require("community.model").Model
local memoize1
memoize1 = require("community.helpers.models").memoize1
local slugify
slugify = require("lapis.util").slugify
local preload
preload = require("lapis.db.model").preload
local VOTE_TYPES_UP = {
  up = true
}
local VOTE_TYPES_BOTH = {
  up = true,
  down = true
}
local VOTE_TYPES_NONE = { }
local parent_enum
parent_enum = function(self, property_name, default, opts)
  local enum_name = next(opts)
  local default_key = "default_" .. tostring(property_name)
  self[default_key] = default
  self[enum_name] = opts[enum_name]
  local method_name = "get_" .. tostring(property_name)
  self.__base[method_name] = function(self)
    do
      local t = self[property_name]
      if t then
        return t
      elseif self.parent_category_id then
        local parent = self:get_parent_category()
        return parent[method_name](parent)
      else
        return self.__class[enum_name]:for_db(self.__class[default_key])
      end
    end
  end
end
local Categories
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
    get_category_group = function(self)
      if not (self.category_groups_count and self.category_groups_count > 0) then
        return 
      end
      do
        local cgc = self:get_category_group_category()
        if cgc then
          return cgc:get_category_group()
        end
      end
    end,
    allowed_to_post_topic = function(self, user, req)
      if not (user) then
        return false
      end
      if self.archived then
        return false
      end
      if self.hidden then
        return false
      end
      if self.directory then
        return false
      end
      local _exp_0 = self:get_topic_posting_type()
      if self.__class.topic_posting_types.everyone == _exp_0 then
        return self:allowed_to_view(user, req)
      elseif self.__class.topic_posting_types.members_only == _exp_0 then
        if self:allowed_to_moderate(user) then
          return true
        end
        return self:is_member(user)
      elseif self.__class.topic_posting_types.moderators_only == _exp_0 then
        return self:allowed_to_moderate(user)
      else
        return error("unknown topic posting type")
      end
    end,
    allowed_to_view = function(self, user, req)
      if self.hidden then
        return false
      end
      local _exp_0 = self.__class.membership_types[self:get_membership_type()]
      if "public" == _exp_0 then
        local _ = nil
      elseif "members_only" == _exp_0 then
        if not (user) then
          return false
        end
        if self:allowed_to_moderate(user) then
          return true
        end
        if not (self:is_member(user)) then
          return false
        end
      end
      if self:get_ban(user) then
        return false
      end
      do
        local category_group = self:get_category_group()
        if category_group then
          if not (category_group:allowed_to_view(user, req)) then
            return false
          end
        end
      end
      return true
    end,
    allowed_to_vote = function(self, user, direction, post)
      if not (user) then
        return false
      end
      if direction == "remove" then
        return true
      end
      local _exp_0 = self:get_voting_type()
      if self.__class.voting_types.up_down == _exp_0 then
        return true
      elseif self.__class.voting_types.up == _exp_0 then
        return direction == "up"
      elseif self.__class.voting_types.up_down_first_post == _exp_0 then
        if post and post:is_topic_post() then
          return true
        end
      else
        return false
      end
    end,
    allowed_to_edit = function(self, user)
      if not (user) then
        return nil
      end
      if user:is_admin() then
        return true
      end
      if user.id == self.user_id then
        return true
      end
      do
        local mod = self:find_moderator(user, {
          accepted = true,
          admin = true
        })
        if mod then
          return true
        end
      end
      return false
    end,
    allowed_to_edit_moderators = function(self, user)
      if self:allowed_to_edit(user) then
        return true
      end
      do
        local mod = self:find_moderator(user, {
          accepted = true,
          admin = true
        })
        if mod then
          return true
        end
      end
      return false
    end,
    allowed_to_edit_members = function(self, user)
      if not (user) then
        return nil
      end
      return self:allowed_to_moderate(user)
    end,
    allowed_to_moderate = function(self, user, ignore_admin)
      if ignore_admin == nil then
        ignore_admin = false
      end
      if not (user) then
        return nil
      end
      if not ignore_admin and user:is_admin() then
        return true
      end
      if user.id == self.user_id then
        return true
      end
      do
        local mod = self:find_moderator(user, {
          accepted = true
        })
        if mod then
          return true
        end
      end
      do
        local group = self:get_category_group()
        if group then
          if group:allowed_to_moderate(user) then
            return true
          end
        end
      end
      return false
    end,
    find_moderator = function(self, user, clause)
      if not (user) then
        return nil
      end
      local Moderators
      Moderators = require("community.models").Moderators
      local opts = {
        object_type = Moderators.object_types.category,
        object_id = self.parent_category_id and db.list(self:get_category_ids()) or self.id,
        user_id = user.id
      }
      if clause then
        for k, v in pairs(clause) do
          opts[k] = v
        end
      end
      return Moderators:find(opts)
    end,
    is_member = function(self, user)
      return self:find_member(user, {
        accepted = true
      })
    end,
    find_member = function(self, user, clause)
      if not (user) then
        return nil
      end
      local CategoryMembers
      CategoryMembers = require("community.models").CategoryMembers
      local opts = {
        category_id = self.parent_category_id and db.list(self:get_category_ids()) or self.id,
        user_id = user.id
      }
      if clause then
        for k, v in pairs(clause) do
          opts[k] = v
        end
      end
      return CategoryMembers:find(opts)
    end,
    find_ban = function(self, user)
      if not (user) then
        return nil
      end
      local Bans
      Bans = require("community.models").Bans
      return Bans:find({
        object_type = Bans.object_types.category,
        object_id = self.parent_category_id and db.list(self:get_category_ids()) or self.id,
        banned_user_id = user.id
      })
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
    get_order_ranges = function(self, status)
      if status == nil then
        status = "default"
      end
      local Topics
      Topics = require("community.models").Topics
      status = Topics.statuses:for_db(status)
      local res = db.query("\n      select sticky, min(category_order), max(category_order)\n      from " .. tostring(db.escape_identifier(Topics:table_name())) .. "\n      where category_id = ? and status = ? and not deleted\n      group by sticky\n    ", self.id, status)
      local ranges = {
        sticky = { },
        regular = { }
      }
      for _index_0 = 1, #res do
        local _des_0 = res[_index_0]
        local sticky, min, max
        sticky, min, max = _des_0.sticky, _des_0.min, _des_0.max
        local r = ranges[sticky and "sticky" or "regular"]
        r.min = min
        r.max = max
      end
      return ranges
    end,
    available_vote_types = function(self, post)
      local _exp_0 = self:get_voting_type()
      if self.__class.voting_types.up_down == _exp_0 then
        return VOTE_TYPES_BOTH
      elseif self.__class.voting_types.up == _exp_0 then
        return VOTE_TYPES_UP
      elseif self.__class.voting_types.up_down_first_post == _exp_0 then
        if post and post:is_topic_post() then
          return VOTE_TYPES_BOTH
        else
          return VOTE_TYPES_NONE
        end
      else
        return VOTE_TYPES_NONE
      end
    end,
    refresh_topic_category_order = function(self)
      local _exp_0 = self.category_order_type
      if self.__class.category_order_types.post_date == _exp_0 then
        return self:refresh_topic_category_order_by_post_date()
      elseif self.__class.category_order_types.topic_score == _exp_0 then
        return self:refresh_topic_category_order_by_topic_score()
      else
        return error("unknown category order type")
      end
    end,
    topic_score_bucket_size = function(self)
      return 45000
    end,
    refresh_topic_category_order_by_topic_score = function(self)
      local Topics, Posts
      do
        local _obj_0 = require("community.models")
        Topics, Posts = _obj_0.Topics, _obj_0.Posts
      end
      local tname = db.escape_identifier(Topics:table_name())
      local posts_tname = db.escape_identifier(Posts:table_name())
      local start = self.__class.score_starting_date
      local time_bucket = self:topic_score_bucket_size()
      local score_query = "(\n      select up_votes_count - down_votes_count + rank_adjustment\n      from " .. tostring(posts_tname) .. " where topic_id = " .. tostring(tname) .. ".id and post_number = 1 and depth = 1 and parent_post_id is null\n    )"
      return db.query("\n      update " .. tostring(tname) .. "\n      set category_order =\n        (\n          (extract(epoch from created_at) - ?) / ? +\n          2 * (case when " .. tostring(score_query) .. " > 0 then 1 else -1 end) * log(greatest(abs(" .. tostring(score_query) .. ") + 1, 1))\n        ) * 1000\n      where category_id = ?\n    ", start, time_bucket, self.id)
    end,
    refresh_topic_category_order_by_post_date = function(self)
      local Topics, Posts
      do
        local _obj_0 = require("community.models")
        Topics, Posts = _obj_0.Topics, _obj_0.Posts
      end
      local tname = db.escape_identifier(Topics:table_name())
      local posts_tname = db.escape_identifier(Posts:table_name())
      db.query("\n      update " .. tostring(tname) .. "\n      set category_order = k.category_order\n      from (\n        select id, row_number() over (order by last_post_at asc) as category_order\n        from\n        (\n          select\n            inside.id,\n            coalesce(\n              (select created_at from " .. tostring(posts_tname) .. " as posts where posts.id = last_post_id),\n              inside.created_at\n            ) as last_post_at\n          from " .. tostring(tname) .. " as inside where category_id = ?\n        ) as t\n      ) k\n      where " .. tostring(tname) .. ".id = k.id\n    ", self.id)
      return self:refresh_last_topic()
    end,
    refresh_last_topic = function(self)
      local Topics
      Topics = require("community.models").Topics
      return self:update({
        last_topic_id = db.raw(db.interpolate_query("(\n        select id from " .. tostring(db.escape_identifier(Topics:table_name())) .. "\n        where\n          category_id = ? and\n          not deleted and\n          status = ?\n        order by category_order desc\n        limit 1\n      )", self.id, Topics.statuses.default))
      }, {
        timestamp = false
      })
    end,
    increment_from_topic = function(self, topic)
      assert(topic.category_id == self.id, "topic does not belong to category")
      self:clear_loaded_relation("last_topic")
      return self:update({
        topics_count = db.raw("topics_count + 1"),
        last_topic_id = topic.id
      }, {
        timestamp = false
      })
    end,
    increment_from_post = function(self, post)
      if post:is_moderation_event() then
        return 
      end
      local CategoryPostLogs
      CategoryPostLogs = require("community.models").CategoryPostLogs
      CategoryPostLogs:log_post(post)
      if not (self.last_topic_id == post.topic_id) then
        self:clear_loaded_relation("last_topic")
        return self:update({
          last_topic_id = post.topic_id
        }, {
          timestamp = false
        })
      end
    end,
    notification_target_users = function(self)
      local hierarchy = {
        self,
        unpack(self:get_ancestors())
      }
      preload(hierarchy, "user", {
        subscriptions = "user"
      })
      local seen_targets = { }
      local subs = { }
      for _index_0 = 1, #hierarchy do
        local c = hierarchy[_index_0]
        local _list_0 = c:get_subscriptions()
        for _index_1 = 1, #_list_0 do
          local sub = _list_0[_index_1]
          table.insert(subs, sub)
        end
      end
      local targets
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #subs do
          local _continue_0 = false
          repeat
            local sub = subs[_index_0]
            if seen_targets[sub.user_id] then
              _continue_0 = true
              break
            end
            seen_targets[sub.user_id] = true
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
      for _index_0 = 1, #hierarchy do
        local _continue_0 = false
        repeat
          local c = hierarchy[_index_0]
          if not (c.user_id) then
            _continue_0 = true
            break
          end
          if seen_targets[c.user_id] then
            _continue_0 = true
            break
          end
          table.insert(targets, c:get_user())
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      return targets
    end,
    get_category_ids = function(self)
      if self.parent_category_id then
        local ids
        do
          local _accum_0 = { }
          local _len_0 = 1
          local _list_0 = self:get_ancestors()
          for _index_0 = 1, #_list_0 do
            local c = _list_0[_index_0]
            _accum_0[_len_0] = c.id
            _len_0 = _len_0 + 1
          end
          ids = _accum_0
        end
        table.insert(ids, self.id)
        return ids
      else
        return {
          self.id
        }
      end
    end,
    get_parent_category = function(self)
      return self:get_ancestors()[1]
    end,
    get_ancestors = function(self)
      if not (self.parent_category_id) then
        return { }
      end
      if not (self.ancestors) then
        self.__class:preload_ancestors({
          self
        })
      end
      return self.ancestors
    end,
    get_children = function(self, opts)
      if self.children then
        return self.children
      end
      local sorter
      sorter = function(a, b)
        return a.position < b.position
      end
      local NestedOrderedPaginator
      NestedOrderedPaginator = require("community.model").NestedOrderedPaginator
      local pager = NestedOrderedPaginator(self.__class, "position", [[      where parent_category_id = ?
    ]], self.id, {
        prepare_results = opts and opts.prepare_results,
        per_page = 1000,
        parent_field = "parent_category_id",
        sort = function(cats)
          return table.sort(cats, sorter)
        end,
        is_top_level_item = function(item)
          return item.parent_category_id == self.id
        end
      })
      self.children = pager:get_page()
      return self.children
    end,
    get_flat_children = function(self, ...)
      self:get_children(...)
      local flat = { }
      local append_children
      append_children = function(cat)
        local _list_0 = cat.children
        for _index_0 = 1, #_list_0 do
          local c = _list_0[_index_0]
          table.insert(flat, c)
          if c.children and next(c.children) then
            append_children(c)
          end
        end
      end
      append_children(self)
      return flat
    end,
    find_last_seen_for_user = function(self, user)
      if not (user) then
        return 
      end
      if not (self.last_topic_id) then
        return 
      end
      local UserCategoryLastSeens
      UserCategoryLastSeens = require("community.models").UserCategoryLastSeens
      local last_seen = UserCategoryLastSeens:find({
        user_id = user.id,
        category_id = self.id
      })
      if last_seen then
        last_seen.category = self
        last_seen.user = user
      end
      return last_seen
    end,
    has_unread = function(self, user)
      if not (user) then
        return 
      end
      if not (self.user_category_last_seen) then
        return 
      end
      if not (self.last_topic_id) then
        return 
      end
      assert(self.user_category_last_seen.user_id == user.id, "unexpected user for last seen")
      return self.user_category_last_seen.category_order < self:get_last_topic().category_order
    end,
    set_seen = function(self, user)
      if not (user) then
        return 
      end
      if not (self.last_topic_id) then
        return 
      end
      local insert_on_conflict_update
      insert_on_conflict_update = require("community.helpers.models").insert_on_conflict_update
      local UserCategoryLastSeens
      UserCategoryLastSeens = require("community.models").UserCategoryLastSeens
      local last_topic = self:get_last_topic()
      return insert_on_conflict_update(UserCategoryLastSeens, {
        user_id = user.id,
        category_id = self.id
      }, {
        topic_id = last_topic.id,
        category_order = last_topic.category_order
      })
    end,
    parse_tags = function(self, str)
      if str == nil then
        str = ""
      end
      local tags_by_slug
      do
        local _tbl_0 = { }
        local _list_0 = self:get_tags()
        for _index_0 = 1, #_list_0 do
          local t = _list_0[_index_0]
          _tbl_0[t.slug] = t
        end
        tags_by_slug = _tbl_0
      end
      local trim
      trim = require("lapis.util").trim
      local parsed
      do
        local _accum_0 = { }
        local _len_0 = 1
        for s in str:gmatch("[^,]+") do
          _accum_0[_len_0] = trim(s)
          _len_0 = _len_0 + 1
        end
        parsed = _accum_0
      end
      local seen = { }
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #parsed do
          local _continue_0 = false
          repeat
            local t = parsed[_index_0]
            t = tags_by_slug[t]
            if not (t) then
              _continue_0 = true
              break
            end
            if seen[t.slug] then
              _continue_0 = true
              break
            end
            seen[t.slug] = true
            local _value_0 = t
            _accum_0[_len_0] = _value_0
            _len_0 = _len_0 + 1
            _continue_0 = true
          until true
          if not _continue_0 then
            break
          end
        end
        parsed = _accum_0
      end
      if next(parsed) then
        return parsed
      end
    end,
    should_log_posts = function(self)
      return self.directory
    end,
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
    order_by_score = function(self)
      return self.category_order_type == self.__class.category_order_types.topic_score
    end,
    order_by_date = function(self)
      return self.category_order_type == self.__class.category_order_types.post_date
    end,
    next_topic_category_order = function(self)
      local Topics
      Topics = require("community.models").Topics
      local _exp_0 = self.category_order_type
      if self.__class.category_order_types.topic_score == _exp_0 then
        return Topics:calculate_score_category_order(0, db.format_date(), self:topic_score_bucket_size())
      elseif self.__class.category_order_types.post_date == _exp_0 then
        return Topics:update_category_order_sql(self.id)
      end
    end,
    update_category_order_type = function(self, category_order)
      category_order = self.__class.category_order_types:for_db(category_order)
      if category_order == self.category_order_type then
        return 
      end
      self:update({
        category_order_type = category_order
      })
      return self:refresh_topic_category_order()
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "Categories",
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
  self.score_starting_date = 1134028003
  parent_enum(self, "membership_type", "public", {
    membership_types = enum({
      public = 1,
      members_only = 2
    })
  })
  parent_enum(self, "topic_posting_type", "everyone", {
    topic_posting_types = enum({
      everyone = 1,
      members_only = 2,
      moderators_only = 3
    })
  })
  parent_enum(self, "voting_type", "up_down", {
    voting_types = enum({
      up_down = 1,
      up = 2,
      disabled = 3,
      up_down_first_post = 4
    })
  })
  parent_enum(self, "approval_type", "none", {
    approval_types = enum({
      none = 1,
      pending = 2
    })
  })
  self.category_order_types = enum({
    post_date = 1,
    topic_score = 2
  })
  self.relations = {
    {
      "moderators",
      has_many = "Moderators",
      key = "object_id",
      where = {
        accepted = true,
        object_type = 1
      }
    },
    {
      "category_group_category",
      has_one = "CategoryGroupCategories"
    },
    {
      "user",
      belongs_to = "Users"
    },
    {
      "last_topic",
      belongs_to = "Topics"
    },
    {
      "parent_category",
      belongs_to = "Categories"
    },
    {
      "tags",
      has_many = "CategoryTags",
      order = "tag_order asc"
    },
    {
      "subscriptions",
      has_many = "Subscriptions",
      key = "object_id",
      where = {
        object_type = 2
      }
    },
    {
      "topics",
      has_many = "Topics",
      order = "category_order desc"
    },
    {
      "active_moderators",
      fetch = function(self)
        local Moderators
        Moderators = require("community.models").Moderators
        local encode_clause
        encode_clause = require("lapis.db").encode_clause
        return Moderators:select("where " .. tostring(encode_clause({
          accepted = true,
          object_type = Moderators.object_types.category,
          object_id = self.parent_category_id and db.list(self:get_category_ids()) or self.id
        })))
      end
    }
  }
  self.next_position = function(self, parent_id)
    return db.raw(db.interpolate_query("\n     (select coalesce(max(position), 0) from " .. tostring(db.escape_identifier(self:table_name())) .. "\n       where parent_category_id = ?) + 1\n    ", parent_id))
  end
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    if opts.membership_type then
      opts.membership_type = self.membership_types:for_db(opts.membership_type)
    end
    if opts.voting_type then
      opts.voting_type = self.voting_types:for_db(opts.voting_type)
    end
    if opts.approval_type then
      opts.approval_type = self.approval_types:for_db(opts.approval_type)
    end
    if opts.title then
      opts.slug = opts.slug or slugify(opts.title)
    end
    if opts.parent_category_id and not opts.position then
      opts.position = self:next_position(opts.parent_category_id)
    end
    if opts.category_order_type then
      opts.category_order_type = self.category_order_types:for_db(opts.category_order_type)
    end
    return Model.create(self, opts)
  end
  self.recount = function(self, ...)
    local Topics, CategoryGroupCategories
    do
      local _obj_0 = require("community.models")
      Topics, CategoryGroupCategories = _obj_0.Topics, _obj_0.CategoryGroupCategories
    end
    local id_field = tostring(db.escape_identifier(self:table_name())) .. ".id"
    return db.update(self:table_name(), {
      topics_count = db.raw("(\n        select count(*) from " .. tostring(db.escape_identifier(Topics:table_name())) .. "\n          where category_id = " .. tostring(id_field) .. "\n      )"),
      deleted_topics_count = db.raw("(\n        select count(*) from " .. tostring(db.escape_identifier(Topics:table_name())) .. "\n          where category_id = " .. tostring(id_field) .. "\n          and deleted\n      )"),
      category_groups_count = db.raw("(\n        select count(*) from " .. tostring(db.escape_identifier(CategoryGroupCategories:table_name())) .. "\n          where category_id = " .. tostring(id_field) .. "\n      )")
    }, ...)
  end
  self.preload_ancestors = function(self, categories)
    local categories_by_id
    do
      local _tbl_0 = { }
      for _index_0 = 1, #categories do
        local c = categories[_index_0]
        _tbl_0[c.id] = c
      end
      categories_by_id = _tbl_0
    end
    local has_parents = false
    local parent_ids
    do
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #categories do
        local _continue_0 = false
        repeat
          local c = categories[_index_0]
          if not (c.parent_category_id) then
            _continue_0 = true
            break
          end
          has_parents = true
          if categories_by_id[c.parent_category_id] then
            _continue_0 = true
            break
          end
          local _value_0 = c.parent_category_id
          _accum_0[_len_0] = _value_0
          _len_0 = _len_0 + 1
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      parent_ids = _accum_0
    end
    if not (has_parents) then
      return 
    end
    if next(parent_ids) then
      local tname = db.escape_identifier(self.__class:table_name())
      local res = db.query("\n        with recursive nested as (\n          (select * from " .. tostring(tname) .. " where id in ?)\n          union\n          select pr.* from " .. tostring(tname) .. " pr, nested\n            where pr.id = nested.parent_category_id\n        )\n        select * from nested\n      ", db.list(parent_ids))
      for _index_0 = 1, #res do
        local category = res[_index_0]
        category = self.__class:load(category)
        local _update_0 = category.id
        categories_by_id[_update_0] = categories_by_id[_update_0] or category
      end
    end
    for _, category in pairs(categories_by_id) do
      local _continue_0 = false
      repeat
        if not (category.parent_category_id) then
          _continue_0 = true
          break
        end
        category.ancestors = { }
        local current = categories_by_id[category.parent_category_id]
        while current do
          table.insert(category.ancestors, current)
          current = categories_by_id[current.parent_category_id]
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    return true
  end
  self.preload_bans = function(self, categories, user)
    if not (user) then
      return 
    end
    if not (next(categories)) then
      return 
    end
    self:preload_ancestors((function()
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #categories do
        local c = categories[_index_0]
        if not c.ancestors then
          _accum_0[_len_0] = c
          _len_0 = _len_0 + 1
        end
      end
      return _accum_0
    end)())
    local categories_by_id = { }
    for _index_0 = 1, #categories do
      local c = categories[_index_0]
      categories_by_id[c.id] = c
      local _list_0 = c:get_ancestors()
      for _index_1 = 1, #_list_0 do
        local ancestor = _list_0[_index_1]
        local _update_0 = ancestor.id
        categories_by_id[_update_0] = categories_by_id[_update_0] or ancestor
      end
    end
    local category_ids
    do
      local _accum_0 = { }
      local _len_0 = 1
      for id in pairs(categories_by_id) do
        _accum_0[_len_0] = id
        _len_0 = _len_0 + 1
      end
      category_ids = _accum_0
    end
    local Bans
    Bans = require("community.models").Bans
    local bans = Bans:select("\n      where banned_user_id = ? and object_type = ? and object_id in ?\n    ", user.id, Bans.object_types.category, db.list(category_ids))
    local bans_by_category_id
    do
      local _tbl_0 = { }
      for _index_0 = 1, #bans do
        local b = bans[_index_0]
        _tbl_0[b.object_id] = b
      end
      bans_by_category_id = _tbl_0
    end
    for _, category in pairs(categories_by_id) do
      category.user_bans = category.user_bans or { }
      category.user_bans[user.id] = bans_by_category_id[category.id] or false
    end
    return true
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Categories = _class_0
  return _class_0
end
