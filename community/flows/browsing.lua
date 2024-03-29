local Flow
Flow = require("lapis.flow").Flow
local Users
Users = require("models").Users
local Categories, Topics, Posts, CommunityUsers
do
  local _obj_0 = require("community.models")
  Categories, Topics, Posts, CommunityUsers = _obj_0.Categories, _obj_0.Topics, _obj_0.Posts, _obj_0.CommunityUsers
end
local OrderedPaginator
OrderedPaginator = require("lapis.db.pagination").OrderedPaginator
local NestedOrderedPaginator
NestedOrderedPaginator = require("community.model").NestedOrderedPaginator
local assert_error
assert_error = require("lapis.application").assert_error
local assert_valid, with_params
do
  local _obj_0 = require("lapis.validate")
  assert_valid, with_params = _obj_0.assert_valid, _obj_0.with_params
end
local uniqify
uniqify = require("lapis.util").uniqify
local preload
preload = require("lapis.db.model").preload
local db = require("lapis.db")
local types = require("lapis.validate.types")
local date = require("date")
local limits = require("community.limits")
local BrowsingFlow
do
  local _class_0
  local _parent_0 = Flow
  local _base_0 = {
    expose_assigns = true,
    allowed_to_view = function(self, obj)
      return obj:allowed_to_view(self.current_user, self._req)
    end,
    throttle_view_count = function(self, key)
      return false
    end,
    get_before_after = with_params({
      {
        "before",
        types.empty + types.db_id
      },
      {
        "after",
        types.empty + types.db_id
      }
    }, function(self, params)
      return params.before, params.after
    end),
    view_counter = function(self)
      local running_in_test
      running_in_test = require("lapis.spec").running_in_test
      local in_test = running_in_test()
      local dict_name
      if in_test then
        dict_name = nil
      else
        local config = require("lapis.config").get()
        if not (config.community) then
          return 
        end
        dict_name = config.community.view_counter_dict
      end
      local AsyncCounter, bulk_increment
      do
        local _obj_0 = require("community.helpers.counters")
        AsyncCounter, bulk_increment = _obj_0.AsyncCounter, _obj_0.bulk_increment
      end
      return AsyncCounter(dict_name, {
        increment_immediately = in_test,
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
    increment_topic_view_counter = function(self, topic)
      if topic == nil then
        topic = self.topic
      end
      assert(topic, "missing topic")
      do
        local view_counter = self:view_counter()
        if view_counter then
          local key = "topic:" .. tostring(topic.id)
          if not (self:throttle_view_count(key)) then
            return view_counter:increment(key)
          end
        end
      end
    end,
    topic_posts = function(self, opts)
      if opts == nil then
        opts = { }
      end
      local mark_seen
      if opts.mark_seen == nil then
        mark_seen = true
      else
        mark_seen = opts.mark_seen
      end
      local order = opts.order or "asc"
      local per_page = opts.per_page or limits.POSTS_PER_PAGE
      local TopicsFlow = require("community.flows.topics")
      TopicsFlow(self):load_topic()
      assert_error(self:allowed_to_view(self.topic), "not allowed to view")
      if opts.increment_views ~= false then
        self:increment_topic_view_counter()
      end
      local before, after = self:get_before_after()
      local params = assert_valid(self.params, types.params_shape({
        {
          "status",
          (types.empty / "default" + types.one_of({
            "archived"
          })) * types.db_enum(Posts.statuses)
        }
      }))
      local pager = NestedOrderedPaginator(Posts, "post_number", "where ?", db.clause({
        topic_id = self.topic.id,
        status = params.status,
        depth = 1
      }), {
        per_page = per_page,
        parent_field = "parent_post_id",
        child_clause = {
          status = params.status
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
          self.last_page = {
            before = max_range + 1
          }
        end
        if next_before then
          self.prev_page = {
            before = next_before > per_page + 1 and next_before or nil
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
          self.last_page = {
            after = 0
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
    preload_categories = function(self, categories, last_seens)
      if last_seens == nil then
        last_seens = true
      end
      preload(categories, "last_topic")
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
      self:preload_topics(topics)
      if last_seens and self.current_user then
        preload((function()
          local _accum_0 = { }
          local _len_0 = 1
          for _index_0 = 1, #categories do
            local c = categories[_index_0]
            _accum_0[_len_0] = c:with_user(self.current_user.id)
            _len_0 = _len_0 + 1
          end
          return _accum_0
        end)(), "last_seen")
      end
      return categories
    end,
    preload_topics = function(self, topics, last_seens)
      if last_seens == nil then
        last_seens = true
      end
      Topics:preload_relation(topics, "last_post", {
        fields = "id, user_id, created_at, updated_at"
      })
      local all_topics
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #topics do
          local t = topics[_index_0]
          _accum_0[_len_0] = t
          _len_0 = _len_0 + 1
        end
        all_topics = _accum_0
      end
      for _index_0 = 1, #topics do
        local t = topics[_index_0]
        if t.last_post then
          table.insert(all_topics, t.last_post)
        end
      end
      preload(all_topics, "user")
      if last_seens and self.current_user then
        preload((function()
          local _accum_0 = { }
          local _len_0 = 1
          for _index_0 = 1, #topics do
            local t = topics[_index_0]
            _accum_0[_len_0] = t:with_user(self.current_user.id)
            _len_0 = _len_0 + 1
          end
          return _accum_0
        end)(), "last_seen")
      end
      return topics
    end,
    preload_posts = function(self, posts)
      preload(posts, "user", "moderation_log")
      for _index_0 = 1, #posts do
        local p = posts[_index_0]
        p.topic = self.topic
      end
      Posts:preload_mentioned_users(posts)
      CommunityUsers:preload_users((function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #posts do
          local p = posts[_index_0]
          if p.user then
            _accum_0[_len_0] = p.user
            _len_0 = _len_0 + 1
          end
        end
        return _accum_0
      end)())
      if self.current_user then
        local Blocks, Votes
        do
          local _obj_0 = require("community.models")
          Blocks, Votes = _obj_0.Blocks, _obj_0.Votes
        end
        local viewers
        do
          local _accum_0 = { }
          local _len_0 = 1
          for _index_0 = 1, #posts do
            local post = posts[_index_0]
            _accum_0[_len_0] = post:with_viewing_user(self.current_user.id)
            _len_0 = _len_0 + 1
          end
          viewers = _accum_0
        end
        preload(viewers, "block_given")
        Votes:preload_post_votes(posts, self.current_user.id)
      end
      return posts
    end,
    sticky_category_topics = function(self, opts)
      if opts == nil then
        opts = { }
      end
      local CategoriesFlow = require("community.flows.categories")
      CategoriesFlow(self):load_category()
      assert_error(self:allowed_to_view(self.category), "not allowed to view")
      local pager = OrderedPaginator(Topics, "category_order", [[      where category_id = ? and status = ? and not deleted and sticky
    ]], self.category.id, Topics.statuses.default, {
        per_page = opts.per_page or limits.TOPICS_PER_PAGE,
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
    preview_category_topics = function(self, category, limit)
      if limit == nil then
        limit = 5
      end
      self.category = category
      assert(self.category, "missing category")
      local status = Topics.statuses:for_db("default")
      local ids
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = self.category:get_flat_children()
        for _index_0 = 1, #_list_0 do
          local c = _list_0[_index_0]
          _accum_0[_len_0] = c.id
          _len_0 = _len_0 + 1
        end
        ids = _accum_0
      end
      table.insert(ids, self.category.id)
      local encode_value_list
      encode_value_list = require("community.helpers.models").encode_value_list
      local topic_tuples = db.query("\n      select unnest(array(\n        select row_to_json(community_topics) from community_topics\n        where category_id = t.category_id\n        and status = ?\n        and not deleted\n        and last_post_id is not null\n        order by category_order desc\n        limit ?\n      )) as topic\n      from (" .. tostring(encode_value_list((function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #ids do
          local id = ids[_index_0]
          _accum_0[_len_0] = {
            id
          }
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)())) .. ") as t(category_id)\n    ", Topics.statuses.default, limit)
      table.sort(topic_tuples, function(a, b)
        return a.topic.last_post_id > b.topic.last_post_id
      end)
      local topics
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _max_0 = limit
        for _index_0 = 1, _max_0 < 0 and #topic_tuples + _max_0 or _max_0 do
          local t = topic_tuples[_index_0]
          if t then
            _accum_0[_len_0] = Topics:load(t.topic)
            _len_0 = _len_0 + 1
          end
        end
        topics = _accum_0
      end
      self:preload_topics(topics)
      return topics
    end,
    category_topics = function(self, opts)
      if opts == nil then
        opts = { }
      end
      local mark_seen
      if opts.mark_seen == nil then
        mark_seen = true
      else
        mark_seen = opts.mark_seen
      end
      local CategoriesFlow = require("community.flows.categories")
      CategoriesFlow(self):load_category()
      assert_error(self:allowed_to_view(self.category), "not allowed to view")
      local params = assert_valid(self.params, types.params_shape({
        {
          "status",
          (types.empty / "default" + types.one_of({
            "archived",
            "hidden"
          })) * types.db_enum(Topics.statuses)
        }
      }))
      self.topics_status = Topics.statuses:to_name(params.status)
      local status = Topics.statuses:for_db(self.topics_status)
      if opts.increment_views ~= false then
        do
          local view_counter = self:view_counter()
          if view_counter then
            local key = "category:" .. tostring(self.category.id)
            if not (self:throttle_view_count(key)) then
              view_counter:increment(key)
            end
          end
        end
      end
      local before, after = self:get_before_after()
      local pager = OrderedPaginator(Topics, "category_order", "where ?", db.clause({
        category_id = self.category.id,
        status = params.status,
        deleted = false,
        sticky = false
      }), {
        per_page = opts.per_page or limits.TOPICS_PER_PAGE,
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
      if mark_seen then
        local last_seen = self.category:find_last_seen_for_user(self.current_user)
        if not last_seen or last_seen:should_update() then
          self.category:set_seen(self.current_user)
        end
      end
      return self.topics
    end,
    post_single = function(self, post)
      self.post = self.post or post
      local PostsFlow = require("community.flows.posts")
      PostsFlow(self):load_post()
      self.topic = self.post:get_topic()
      assert_error(self:allowed_to_view(self.post), "not allowed to view")
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
      assert_error(self:allowed_to_view(self.category), "not allowed to view")
      self.category:get_children({
        prepare_results = (function()
          local _base_1 = self
          local _fn_0 = _base_1.preload_categories
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)()
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
