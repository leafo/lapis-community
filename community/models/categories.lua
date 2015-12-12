local db = require("lapis.db")
local enum
enum = require("lapis.db.model").enum
local Model
Model = require("community.model").Model
local slugify
slugify = require("lapis.util").slugify
local parent_enum
parent_enum = function(self, property_name, default, opts)
  local enum_name = next(opts)
  self["default_" .. tostring(property_name)] = default
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
        return self.__class[enum_name][default]
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
    allowed_to_post_topic = function(self, user)
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
        return self:allowed_to_view(user)
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
    allowed_to_view = function(self, user)
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
      if self:find_ban(user) then
        return false
      end
      do
        local category_group = self:get_category_group()
        if category_group then
          if not (category_group:allowed_to_view(user)) then
            return false
          end
        end
      end
      return true
    end,
    allowed_to_vote = function(self, user, direction)
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
      return false
    end,
    allowed_to_edit_moderators = function(self, user)
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
    available_vote_types = function(self)
      local _exp_0 = self:get_voting_type()
      if self.__class.voting_types.up_down == _exp_0 then
        return {
          up = true,
          down = true
        }
      elseif self.__class.voting_types.up == _exp_0 then
        return {
          up = true
        }
      else
        return { }
      end
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
      assert(topic.category_id == self.id)
      local clear_loaded_relation
      clear_loaded_relation = require("lapis.db.model.relations").clear_loaded_relation
      clear_loaded_relation(self, "last_topic")
      return self:update({
        topics_count = db.raw("topics_count + 1"),
        last_topic_id = topic.id
      }, {
        timestamp = false
      })
    end,
    increment_from_post = function(self, post)
      return self:update({
        last_topic_id = post.topic_id
      }, {
        timestamp = false
      })
    end,
    notification_target_users = function(self)
      return {
        self:get_user()
      }
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
      local upsert
      upsert = require("community.helpers.models").upsert
      local UserCategoryLastSeens
      UserCategoryLastSeens = require("community.models").UserCategoryLastSeens
      local last_topic = self:get_last_topic()
      return upsert(UserCategoryLastSeens, {
        user_id = user.id,
        category_id = self.id,
        topic_id = last_topic.id,
        category_order = last_topic.category_order
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
      disabled = 3
    })
  })
  parent_enum(self, "approval_type", "none", {
    approval_types = enum({
      none = 1,
      pending = 2
    })
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
    return Model.create(self, opts)
  end
  self.recount = function(self)
    local Topics
    Topics = require("community.models").Topics
    return db.update(self:table_name(), {
      topics_count = db.raw("\n        (select count(*) from " .. tostring(db.escape_identifier(Topics:table_name())) .. "\n          where category_id = " .. tostring(db.escape_identifier(self:table_name())) .. ".id)\n      ")
    })
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
        categories_by_id[category.id] = categories_by_id[category.id] or category
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
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Categories = _class_0
  return _class_0
end
