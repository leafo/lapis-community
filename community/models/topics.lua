local db = require("lapis.db")
local Model
Model = require("community.model").Model
local slugify
slugify = require("lapis.util").slugify
local memoize1
memoize1 = require("community.helpers.models").memoize1
local Topics
do
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
        if self:find_ban(user) then
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
      if user.id == self.user_id then
        return true
      end
      if user:is_admin() then
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
      local category_order
      if not (opts and opts.update_category_order == false) then
        category_order = Topics:update_category_order_sql(self.category_id)
      end
      return self:update({
        posts_count = db.raw("posts_count + 1"),
        root_posts_count = (function()
          if post.depth == 1 then
            return db.raw("root_posts_count + 1")
          end
        end)(),
        last_post_id = post.id,
        category_order = category_order
      }, {
        timestamp = false
      })
    end,
    refresh_last_post = function(self)
      local Posts
      Posts = require("community.models").Posts
      return self:update({
        last_post_id = db.raw(db.interpolate_query("(\n        select id from " .. tostring(db.escape_identifier(Posts:table_name())) .. "\n        where topic_id = ? and not deleted and (depth != 1 or post_number != 1)\n        order by id desc\n        limit 1\n      )", self.id))
      }, {
        timestamp = false
      })
    end,
    delete = function(self)
      local soft_delete
      soft_delete = require("community.helpers.models").soft_delete
      if soft_delete(self) then
        self:update({
          deleted_at = db.format_date()
        }, {
          timestamp = false
        })
        local CommunityUsers, Categories
        do
          local _obj_0 = require("community.models")
          CommunityUsers, Categories = _obj_0.CommunityUsers, _obj_0.Categories
        end
        if self.user_id then
          CommunityUsers:for_user(self:get_user()):increment("topics_count", -1)
        end
        if self.category_id then
          Categories:load({
            id = self.category_id
          }):update({
            deleted_topics_count = db.raw("deleted_topics_count + 1")
          }, {
            timestamp = false
          })
        end
        return true
      end
      return false
    end,
    get_tags = function(self)
      if not (self.tags) then
        local TopicTags
        TopicTags = require("community.models").TopicTags
        self.tags = TopicTags:select("where topic_id = ?", self.id)
      end
      return self.tags
    end,
    set_tags = function(self, tags_str)
      local TopicTags
      TopicTags = require("community.models").TopicTags
      local tags = TopicTags:parse(tags_str)
      local old_tags
      do
        local _tbl_0 = { }
        local _list_0 = self:get_tags()
        for _index_0 = 1, #_list_0 do
          local tag = _list_0[_index_0]
          _tbl_0[tag.slug] = true
        end
        old_tags = _tbl_0
      end
      local new_tags
      do
        local _tbl_0 = { }
        for _index_0 = 1, #tags do
          local tag = tags[_index_0]
          _tbl_0[TopicTags:slugify(tag)] = tag
        end
        new_tags = _tbl_0
      end
      for slug in pairs(new_tags) do
        if slug:match("^%-*$") or old_tags[slug] then
          new_tags[slug] = nil
          old_tags[slug] = nil
        end
      end
      if next(old_tags) then
        local slugs = table.concat((function()
          local _accum_0 = { }
          local _len_0 = 1
          for slug in pairs(old_tags) do
            _accum_0[_len_0] = db.escape_literal(slug)
            _len_0 = _len_0 + 1
          end
          return _accum_0
        end)(), ",")
        db.delete(TopicTags:table_name(), "topic_id = ? and slug in (" .. tostring(slugs) .. ")", self.id)
      end
      for slug, label in pairs(new_tags) do
        TopicTags:create({
          topic_id = self.id,
          label = label,
          slug = slug
        })
      end
      self.tags = nil
      return true
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
    available_vote_types = function(self)
      do
        local category = self:get_category()
        if category then
          return category:available_vote_types()
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
      local upsert
      upsert = require("community.helpers.models").upsert
      local UserTopicLastSeens
      UserTopicLastSeens = require("community.models").UserTopicLastSeens
      return upsert(UserTopicLastSeens, {
        user_id = user.id,
        topic_id = self.id,
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
      return self.user_topic_last_seen.post_id < self.last_post_id
    end,
    notification_target_users = function(self)
      return {
        self:get_user()
      }
    end,
    find_latest_root_post = function(self)
      local Posts
      Posts = require("community.models").Posts
      return unpack(Posts:select("\n      where topic_id = ? and depth = 1 order by post_number desc limit 1\n    ", self.id))
    end,
    get_topic_post = function(self)
      if not (self.topic_post) then
        local Posts
        Posts = require("community.models").Posts
        self.topic_post = Posts:find({
          topic_id = self.id,
          depth = 1,
          post_number = 1
        })
      end
      return self.topic_post
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
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  local _class_0 = setmetatable({
    __init = function(self, ...)
      return _parent_0.__init(self, ...)
    end,
    __base = _base_0,
    __name = "Topics",
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
  self.relations = {
    {
      "category",
      belongs_to = "Categories"
    },
    {
      "user",
      belongs_to = "Users"
    }
  }
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    if opts.title then
      opts.slug = opts.slug or slugify(opts.title)
    end
    opts.category_order = self:update_category_order_sql(opts.category_id)
    return Model.create(self, opts)
  end
  self.update_category_order_sql = function(self, category_id)
    if not (category_id) then
      return nil
    end
    return db.raw(db.interpolate_query("\n      (select coalesce(max(category_order), 0) + 1\n      from " .. tostring(db.escape_identifier(self:table_name())) .. "\n      where category_id = ?)\n    ", category_id))
  end
  self.recount = function(self, where)
    local Posts
    Posts = require("community.models").Posts
    return db.update(self:table_name(), {
      root_posts_count = db.raw("\n        (select count(*) from " .. tostring(db.escape_identifier(Posts:table_name())) .. "\n          where topic_id = " .. tostring(db.escape_identifier(self:table_name())) .. ".id\n          and depth = 1)\n      "),
      posts_count = db.raw("\n        (select count(*) from " .. tostring(db.escape_identifier(Posts:table_name())) .. "\n          where topic_id = " .. tostring(db.escape_identifier(self:table_name())) .. ".id)\n      ")
    }, where)
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Topics = _class_0
  return _class_0
end
