local db = require("lapis.db")
local enum
enum = require("lapis.db.model").enum
local Model
Model = require("community.model").Model
local slugify
slugify = require("lapis.util").slugify
local Categories
do
  local _parent_0 = Model
  local _base_0 = {
    get_category_group = function(self)
      do
        local cgc = self:get_category_group_category()
        if cgc then
          return cgc:get_category_group()
        end
      end
    end,
    allowed_to_post = function(self, user)
      if not (user) then
        return false
      end
      if self.archived then
        return false
      end
      if self.hidden then
        return false
      end
      return self:allowed_to_view(user)
    end,
    allowed_to_view = function(self, user)
      if self.hidden then
        return false
      end
      local _exp_0 = self.__class.membership_types[self.membership_type]
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
      local _exp_0 = self.voting_type
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
      local member = self:find_member(user)
      return member and member.accepted
    end,
    find_member = function(self, user)
      if not (user) then
        return nil
      end
      local CategoryMembers
      CategoryMembers = require("community.models").CategoryMembers
      return CategoryMembers:find({
        category_id = self.id,
        user_id = user.id
      })
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
    get_order_ranges = function(self)
      local Topics
      Topics = require("community.models").Topics
      local res = db.query("\n      select sticky, min(category_order), max(category_order)\n      from " .. tostring(db.escape_identifier(Topics:table_name())) .. "\n      where category_id = ? and not deleted\n      group by sticky\n    ", self.id)
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
      local _exp_0 = self.voting_type
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
        last_topic_id = db.raw(db.interpolate_query("(\n        select id from " .. tostring(db.escape_identifier(Topics:table_name())) .. " where category_id = ? and not deleted\n        order by category_order desc\n        limit 1\n      )", self.id))
      }, {
        timestamp = false
      })
    end,
    increment_from_topic = function(self, topic)
      assert(topic.category_id == self.id)
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
    get_ancestors = function(self)
      if not (self.parent_category_id) then
        return { }
      end
      if not (self.ancestors) then
        local tname = db.escape_identifier(self.__class:table_name())
        local res = db.query("\n        with recursive nested as (\n          (select * from " .. tostring(tname) .. " where id = ?)\n          union\n          select pr.* from " .. tostring(tname) .. " pr, nested\n            where pr.id = nested.parent_category_id\n        )\n        select * from nested\n      ", self.parent_category_id)
        do
          local _accum_0 = { }
          local _len_0 = 1
          for _index_0 = 1, #res do
            local category = res[_index_0]
            _accum_0[_len_0] = self.__class:load(category)
            _len_0 = _len_0 + 1
          end
          self.ancestors = _accum_0
        end
      end
      return self.ancestors
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  local _class_0 = setmetatable({
    __init = function(self, ...)
      return _parent_0.__init(self, ...)
    end,
    __base = _base_0,
    __name = "Categories",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        return _parent_0[name]
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
  self.membership_types = enum({
    public = 1,
    members_only = 2
  })
  self.voting_types = enum({
    up_down = 1,
    up = 2,
    disabled = 3
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
    }
  }
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    assert(opts.title, "missing title")
    opts.membership_type = self.membership_types:for_db(opts.membership_type or "public")
    opts.voting_type = self.voting_types:for_db(opts.voting_type or "up_down")
    opts.slug = opts.slug or slugify(opts.title)
    return Model.create(self, opts)
  end
  self.preload_last_topics = function(self, categories)
    local Topics
    Topics = require("community.models").Topics
    return Topics:include_in(categories, "last_topic_id", {
      as = "last_topic"
    })
  end
  self.recount = function(self)
    local Topics
    Topics = require("community.models").Topics
    return db.update(self:table_name(), {
      topics_count = db.raw("\n        (select count(*) from " .. tostring(db.escape_identifier(Topics:table_name())) .. "\n          where category_id = " .. tostring(db.escape_identifier(self:table_name())) .. ".id)\n      ")
    })
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Categories = _class_0
  return _class_0
end
