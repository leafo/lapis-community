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
local NestedOrderedPaginator
NestedOrderedPaginator = require("community.model").NestedOrderedPaginator
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
local BrowsingFlow
do
  local _class_0
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
    topic_pending_posts = function(self)
      local TopicsFlow = require("community.flows.topics")
      TopicsFlow(self):load_topic()
      if not (self.current_user) then
        return 
      end
      local PendingPosts
      PendingPosts = require("community.models").PendingPosts
      self.pending_posts = PendingPosts:select("where topic_id = ? and user_id = ?", self.topic.id, self.current_user.id)
      return self.pending_posts
    end,
    topic_posts = function(self, mark_seen, order)
      if mark_seen == nil then
        mark_seen = true
      end
      if order == nil then
        order = "asc"
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
      assert_valid(self.params, {
        {
          "status",
          optional = true,
          one_of = {
            "archived"
          }
        }
      })
      local status = Posts.statuses:for_db(self.params.status or "default")
      local pager = NestedOrderedPaginator(Posts, "post_number", [[      where topic_id = ? and depth = 1 and status = ?
    ]], self.topic.id, status, {
        per_page = limits.POSTS_PER_PAGE,
        parent_field = "parent_post_id",
        child_clause = {
          status = status
        },
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
      local min_range, max_range = self.topic:get_root_order_ranges()
      local _exp_0 = order
      if "asc" == _exp_0 then
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
        local next_after
        do
          local p = self.posts[#self.posts]
          if p then
            next_after = p.post_number
          end
        end
        if next_after == max_range then
          next_after = nil
        end
        local next_before
        do
          local p = self.posts[1]
          if p then
            next_before = p.post_number
          end
        end
        if next_before == min_range then
          next_before = nil
        end
        if next_after then
          self.next_page = {
            after = next_after
          }
        end
        if next_before then
          self.prev_page = {
            before = next_before > limits.POSTS_PER_PAGE + 1 and next_before or nil
          }
        end
      elseif "desc" == _exp_0 then
        if after then
          self.posts = pager:after(after)
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
          self.posts = pager:before(before)
        end
        local next_before
        do
          local p = self.posts[#self.posts]
          if p then
            next_before = p.post_number
          end
        end
        if next_before == min_range then
          next_before = nil
        end
        local next_after
        do
          local p = self.posts[1]
          if p then
            next_after = p.post_number
          end
        end
        if next_after == max_range then
          next_after = nil
        end
        if next_before then
          self.next_page = {
            before = next_before
          }
        end
        if next_after then
          self.prev_page = {
            after = next_after
          }
        end
      else
        error("unknown order: " .. tostring(order))
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
      local pager = OrderedPaginator(Topics, "category_order", [[      where category_id = ? and status = ? not deleted and sticky
    ]], self.category.id, Topics.statuses.default, {
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
      assert_valid(self.params, {
        {
          "status",
          optional = true,
          one_of = {
            "archived"
          }
        }
      })
      local status = Topics.statuses:for_db(self.params.status or "default")
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
      local pager = OrderedPaginator(Topics, "category_order", [[      where category_id = ? and status = ? and not deleted and not sticky
    ]], self.category.id, status, {
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
      local ranges = self.category:get_order_ranges(status)
      local min, max = ranges.regular.min, ranges.regular.max
      local next_after
      do
        local t = self.topics[1]
        if t then
          next_after = t.category_order
        end
      end
      if max and next_after and next_after >= max then
        next_after = nil
      end
      local next_before
      do
        local t = self.topics[#self.topics]
        if t then
          next_before = t.category_order
        end
      end
      if min and next_before and next_before <= min then
        next_before = nil
      end
      if next_before then
        self.next_page = {
          before = next_before
        }
      end
      if next_after then
        self.prev_page = {
          after = next_after
        }
      end
      return self.topics
    end,
    post_single = function(self, post)
      self.post = self.post or post
      local PostsFlow = require("community.flows.posts")
      PostsFlow(self):load_post()
      self.topic = self.post:get_topic()
      assert_error(self.post:allowed_to_view(self.current_user), "not allowed to view")
      local status
      if self.post:is_archived() then
        status = db.list({
          Posts.statuses.archived,
          Posts.statuses.default
        })
      else
        status = db.list({
          self.post.status
        })
      end
      local all_posts
      local pager = NestedOrderedPaginator(Posts, "post_number", [[      where parent_post_id = ? and status in ?
    ]], self.post.id, status, {
        per_page = limits.POSTS_PER_PAGE,
        parent_field = "parent_post_id",
        child_clause = {
          status = status
        },
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
    end,
    category_single = function(self)
      local CategoriesFlow = require("community.flows.categories")
      CategoriesFlow(self):load_category()
      self.category:get_children({
        prepare_results = function(categories)
          Topics:include_in(categories, "last_topic_id")
          local topics
          do
            local _accum_0 = { }
            local _len_0 = 1
            for _index_0 = 1, #categories do
              local c = categories[_index_0]
              if c.last_topic then
                _accum_0[_len_0] = c.last_topic
                _len_0 = _len_0 + 1
              end
            end
            topics = _accum_0
          end
          Posts:include_in(topics, "last_post_id")
          local posts
          do
            local _accum_0 = { }
            local _len_0 = 1
            for _index_0 = 1, #topics do
              local topic = topics[_index_0]
              if topic.last_post then
                _accum_0[_len_0] = topic.last_post
                _len_0 = _len_0 + 1
              end
            end
            posts = _accum_0
          end
          Users:include_in(posts, "user_id")
          return categories
        end
      })
      return true
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "BrowsingFlow",
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
  BrowsingFlow = _class_0
  return _class_0
end
