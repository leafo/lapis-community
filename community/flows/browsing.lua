local Flow
Flow = require("lapis.flow").Flow
local Users
Users = require("models").Users
local Categories, Topics, Posts
do
  local _obj_0 = require("community.models")
  Categories, Topics, Posts = _obj_0.Categories, _obj_0.Topics, _obj_0.Posts
end
local OrderedPaginator
OrderedPaginator = require("lapis.db.pagination").OrderedPaginator
local assert_error, yield_error
do
  local _obj_0 = require("lapis.application")
  assert_error, yield_error = _obj_0.assert_error, _obj_0.yield_error
end
local assert_valid
assert_valid = require("lapis.validate").assert_valid
local uniqify
uniqify = require("lapis.util").uniqify
local db = require("lapis.db")
local date = require("date")
local limits = require("community.limits")
local NestedOrderedPaginator
do
  local _parent_0 = OrderedPaginator
  local _base_0 = {
    prepare_results = function(self, items)
      items = _parent_0.prepare_results(self, items)
      local parent_field = self.opts.parent_field
      local child_field = self.opts.child_field or "children"
      local by_parent = { }
      local top_level
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #items do
          local _continue_0 = false
          repeat
            local item = items[_index_0]
            do
              local pid = item[parent_field]
              if pid then
                by_parent[pid] = by_parent[pid] or { }
                table.insert(by_parent[pid], item)
              end
            end
            if self.opts.is_top_level_item then
              if not (self.opts.is_top_level_item(item)) then
                _continue_0 = true
                break
              end
            else
              if item[parent_field] then
                _continue_0 = true
                break
              end
            end
            local _value_0 = item
            _accum_0[_len_0] = _value_0
            _len_0 = _len_0 + 1
            _continue_0 = true
          until true
          if not _continue_0 then
            break
          end
        end
        top_level = _accum_0
      end
      for _index_0 = 1, #items do
        local item = items[_index_0]
        item[child_field] = by_parent[item.id]
        do
          local children = self.opts.sort and item[child_field]
          if children then
            self.opts.sort(children)
          end
        end
      end
      return top_level
    end,
    select = function(self, q, opts)
      local tname = db.escape_identifier(self.model:table_name())
      local parent_field = assert(self.opts.parent_field, "missing parent_field")
      local child_field = self.opts.child_field or "children"
      local res = db.query("\n      with recursive nested as (\n        (select * from " .. tostring(tname) .. " " .. tostring(q) .. ")\n        union\n        select pr.* from " .. tostring(tname) .. " pr, nested\n          where pr." .. tostring(db.escape_identifier(parent_field)) .. " = nested.id\n      )\n      select * from nested\n    ")
      for _index_0 = 1, #res do
        local r = res[_index_0]
        self.model:load(r)
      end
      return res
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  local _class_0 = setmetatable({
    __init = function(self, ...)
      return _parent_0.__init(self, ...)
    end,
    __base = _base_0,
    __name = "NestedOrderedPaginator",
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
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  NestedOrderedPaginator = _class_0
end
local BrowsingFlow
do
  local _parent_0 = Flow
  local _base_0 = {
    expose_assigns = true,
    throttle_view_count = function(self, key)
      return false
    end,
    get_before_after = function(self)
      assert_valid(self.params, {
        {
          "before",
          optional = true,
          is_integer = true
        },
        {
          "after",
          optional = true,
          is_integer = true
        }
      })
      return tonumber(self.params.before), tonumber(self.params.after)
    end,
    view_counter = function(self)
      local config = require("lapis.config").get()
      if not (config.community) then
        return 
      end
      local dict_name = config.community.view_counter_dict
      local AsyncCounter, bulk_increment
      do
        local _obj_0 = require("community.helpers.counters")
        AsyncCounter, bulk_increment = _obj_0.AsyncCounter, _obj_0.bulk_increment
      end
      return AsyncCounter(dict_name, {
        sync_types = {
          topic = function(updates)
            return bulk_increment(Topics, "views_count", updates)
          end,
          category = function(updates)
            return bulk_increment(Categories, "views_count", updates)
          end
        }
      })
    end,
    topic_posts = function(self, mark_seen)
      if mark_seen == nil then
        mark_seen = true
      end
      local TopicsFlow = require("community.flows.topics")
      TopicsFlow(self):load_topic()
      assert_error(self.topic:allowed_to_view(self.current_user), "not allowed to view")
      do
        local view_counter = self:view_counter()
        if view_counter then
          local key = "topic:" .. tostring(self.topic.id)
          if not (self:throttle_view_count(key)) then
            view_counter:increment(key)
          end
        end
      end
      local before, after = self:get_before_after()
      local pager = NestedOrderedPaginator(Posts, "post_number", [[      where topic_id = ? and depth = 1
    ]], self.topic.id, {
        per_page = limits.POSTS_PER_PAGE,
        parent_field = "parent_post_id",
        sort = function(list)
          return table.sort(list, function(a, b)
            return a.post_number < b.post_number
          end)
        end,
        prepare_results = (function()
          local _base_1 = self
          local _fn_0 = _base_1.preload_posts
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)()
      })
      if before then
        self.posts = pager:before(before)
        do
          local _accum_0 = { }
          local _len_0 = 1
          for i = #self.posts, 1, -1 do
            _accum_0[_len_0] = self.posts[i]
            _len_0 = _len_0 + 1
          end
          self.posts = _accum_0
        end
      else
        self.posts = pager:after(after)
      end
      do
        local p = self.posts[#self.posts]
        if p then
          self.after = p.post_number
        end
      end
      if self.after == self.topic.root_posts_count then
        self.after = nil
      end
      do
        local p = self.posts[1]
        if p then
          self.before = p.post_number
        end
      end
      if self.before == 1 then
        self.before = nil
      end
      if mark_seen and self.current_user then
        local UserTopicLastSeens
        UserTopicLastSeens = require("community.models").UserTopicLastSeens
        local last_seen = UserTopicLastSeens:find({
          user_id = self.current_user.id,
          topic_id = self.topic.id
        })
        if not last_seen or last_seen.post_id ~= self.topic.last_post_id then
          return self.topic:set_seen(self.current_user)
        end
      end
    end,
    preload_topics = function(self, topics)
      Posts:include_in(topics, "last_post_id")
      local with_users
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #topics do
          local t = topics[_index_0]
          _accum_0[_len_0] = t
          _len_0 = _len_0 + 1
        end
        with_users = _accum_0
      end
      for _index_0 = 1, #topics do
        local t = topics[_index_0]
        if t.last_post then
          table.insert(with_users, t.last_post)
        end
      end
      Users:include_in(with_users, "user_id")
      if self.current_user then
        local UserTopicLastSeens
        UserTopicLastSeens = require("community.models").UserTopicLastSeens
        UserTopicLastSeens:include_in(topics, "topic_id", {
          flip = true,
          where = {
            user_id = self.current_user.id
          }
        })
      end
      return topics
    end,
    preload_posts = function(self, posts)
      Users:include_in(posts, "user_id")
      for _index_0 = 1, #posts do
        local p = posts[_index_0]
        p.topic = self.topic
      end
      Posts:preload_mentioned_users(posts)
      if self.current_user then
        local posts_with_votes
        do
          local _accum_0 = { }
          local _len_0 = 1
          for _index_0 = 1, #posts do
            local p = posts[_index_0]
            if p.down_votes_count > 0 or p.up_votes_count > 0 then
              _accum_0[_len_0] = p
              _len_0 = _len_0 + 1
            end
          end
          posts_with_votes = _accum_0
        end
        local Blocks, Votes
        do
          local _obj_0 = require("community.models")
          Blocks, Votes = _obj_0.Blocks, _obj_0.Votes
        end
        Votes:include_in(posts_with_votes, "object_id", {
          flip = true,
          where = {
            object_type = Votes.object_types.post,
            user_id = self.current_user.id
          }
        })
        Blocks:include_in(posts, "blocked_user_id", {
          flip = true,
          local_key = "user_id",
          where = {
            blocking_user_id = self.current_user.id
          }
        })
      end
      return posts
    end,
    sticky_category_topics = function(self)
      local pager = OrderedPaginator(Topics, "category_order", [[      where category_id = ? and not deleted and sticky
    ]], self.category.id, {
        per_page = limits.TOPICS_PER_PAGE,
        prepare_results = (function()
          local _base_1 = self
          local _fn_0 = _base_1.preload_topics
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)()
      })
      self.sticky_topics = pager:before()
    end,
    category_topics = function(self)
      local CategoriesFlow = require("community.flows.categories")
      CategoriesFlow(self):load_category()
      assert_error(self.category:allowed_to_view(self.current_user), "not allowed to view")
      do
        local view_counter = self:view_counter()
        if view_counter then
          local key = "category:" .. tostring(self.category.id)
          if not (self:throttle_view_count(key)) then
            view_counter:increment(key)
          end
        end
      end
      local before, after = self:get_before_after()
      local pager = OrderedPaginator(Topics, "category_order", [[      where category_id = ? and not deleted and not sticky
    ]], self.category.id, {
        per_page = limits.TOPICS_PER_PAGE,
        prepare_results = (function()
          local _base_1 = self
          local _fn_0 = _base_1.preload_topics
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)()
      })
      if after then
        self.topics = pager:after(after)
        do
          local _accum_0 = { }
          local _len_0 = 1
          for i = #self.topics, 1, -1 do
            _accum_0[_len_0] = self.topics[i]
            _len_0 = _len_0 + 1
          end
          self.topics = _accum_0
        end
      else
        self.topics = pager:before(before)
      end
      local ranges = self.category:get_order_ranges()
      local min, max = ranges.regular.min, ranges.regular.max
      do
        local t = self.topics[1]
        if t then
          self.after = t.category_order
        end
      end
      if max and self.after and self.after >= max then
        self.after = nil
      end
      do
        local t = self.topics[#self.topics]
        if t then
          self.before = t.category_order
        end
      end
      if min and self.before and self.before <= min then
        self.before = nil
      end
      return self.topics
    end,
    post_single = function(self, post)
      self.post = self.post or post
      local PostsFlow = require("community.flows.posts")
      PostsFlow(self):load_post()
      self.topic = self.post:get_topic()
      assert_error(self.post:allowed_to_view(self.current_user), "not allowed to view")
      local all_posts
      local pager = NestedOrderedPaginator(Posts, "post_number", [[      where parent_post_id = ?
    ]], self.post.id, {
        per_page = limits.POSTS_PER_PAGE,
        parent_field = "parent_post_id",
        sort = function(list)
          return table.sort(list, function(a, b)
            return a.post_number < b.post_number
          end)
        end,
        is_top_level_item = function(post)
          return post.parent_post_id == self.post.id
        end,
        prepare_results = function(posts)
          do
            local _accum_0 = { }
            local _len_0 = 1
            for _index_0 = 1, #posts do
              local p = posts[_index_0]
              _accum_0[_len_0] = p
              _len_0 = _len_0 + 1
            end
            all_posts = _accum_0
          end
          return posts
        end
      })
      local children = pager:get_page()
      if all_posts then
        table.insert(all_posts, self.post)
      else
        all_posts = {
          self.post
        }
      end
      self:preload_posts(all_posts)
      self.post.children = children
      return true
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  local _class_0 = setmetatable({
    __init = function(self, ...)
      return _parent_0.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BrowsingFlow",
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
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  BrowsingFlow = _class_0
  return _class_0
end
