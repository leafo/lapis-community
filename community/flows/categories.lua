local Flow
Flow = require("lapis.flow").Flow
local Users
Users = require("models").Users
local Categories, Posts, CategoryMembers, ActivityLogs
do
  local _obj_0 = require("community.models")
  Categories, Posts, CategoryMembers, ActivityLogs = _obj_0.Categories, _obj_0.Posts, _obj_0.CategoryMembers, _obj_0.ActivityLogs
end
local assert_error, yield_error
do
  local _obj_0 = require("lapis.application")
  assert_error, yield_error = _obj_0.assert_error, _obj_0.yield_error
end
local assert_valid
assert_valid = require("lapis.validate").assert_valid
local trim_filter, slugify
do
  local _obj_0 = require("lapis.util")
  trim_filter, slugify = _obj_0.trim_filter, _obj_0.slugify
end
local assert_page, require_login
do
  local _obj_0 = require("community.helpers.app")
  assert_page, require_login = _obj_0.assert_page, _obj_0.require_login
end
local filter_update
filter_update = require("community.helpers.models").filter_update
local preload
preload = require("lapis.db.model").preload
local limits = require("community.limits")
local db = require("lapis.db")
local VALIDATIONS = {
  {
    "title",
    exists = true,
    max_length = limits.MAX_TITLE_LEN
  },
  {
    "short_description",
    optional = true,
    max_length = limits.MAX_TITLE_LEN
  },
  {
    "description",
    optional = true,
    max_length = limits.MAX_BODY_LEN
  },
  {
    "membership_type",
    one_of = Categories.membership_types
  },
  {
    "voting_type",
    one_of = Categories.voting_types
  }
}
local CategoriesFlow
do
  local _class_0
  local _parent_0 = Flow
  local _base_0 = {
    expose_assigns = true,
    moderators_flow = function(self)
      self:load_category()
      local ModeratorsFlow = require("community.flows.moderators")
      return ModeratorsFlow(self, self.category)
    end,
    members_flow = function(self)
      self:load_category()
      local MembersFlow = require("community.flows.members")
      return MembersFlow(self, self)
    end,
    bans_flow = function(self)
      self:load_category()
      local BansFlow = require("community.flows.bans")
      return BansFlow(self, self.category)
    end,
    load_category = function(self)
      if self.category then
        return 
      end
      assert_valid(self.params, {
        {
          "category_id",
          is_integer = true
        }
      })
      self.category = Categories:find(self.params.category_id)
      return assert_error(self.category, "invalid category")
    end,
    recent_posts = function(self, opts)
      self:load_category()
      assert_error(self.category:allowed_to_view(self.current_user, self._req), "invalid category")
      assert_error(self.category:should_log_posts(), "category has no log")
      local CategoryPostLogs
      CategoryPostLogs = require("community.models").CategoryPostLogs
      local OrderedPaginator
      OrderedPaginator = require("lapis.db.pagination").OrderedPaginator
      local clauses = {
        db.interpolate_query("category_id = ?", self.category.id)
      }
      do
        local f = opts and opts.filter
        if f then
          local _exp_0 = opts and opts.filter
          if "topics" == _exp_0 then
            table.insert(clauses, "posts.post_number = 1 and posts.depth = 1")
          elseif "replies" == _exp_0 then
            table.insert(clauses, "(posts.post_number > 1 or posts.depth > 1)")
          else
            error("unknown filter: " .. tostring(f))
          end
        end
      end
      if opts and opts.after_date then
        table.insert(clauses, db.interpolate_query("(select created_at from " .. tostring(db.escape_identifier(Posts:table_name())) .. " as posts where posts.id = post_id) > ?", opts.after_date))
      end
      local query = "inner join " .. tostring(db.escape_identifier(Posts:table_name())) .. " as posts on posts.id = post_id\n      where " .. tostring(table.concat(clauses, " and "))
      self.pager = OrderedPaginator(CategoryPostLogs, "post_id", query, {
        fields = "post_id",
        per_page = opts and opts.per_page or limits.TOPICS_PER_PAGE,
        order = "desc",
        prepare_results = function(logs)
          preload(logs, "post")
          local posts
          do
            local _accum_0 = { }
            local _len_0 = 1
            for _index_0 = 1, #logs do
              local log = logs[_index_0]
              if log:get_post() then
                _accum_0[_len_0] = log:get_post()
                _len_0 = _len_0 + 1
              end
            end
            posts = _accum_0
          end
          self:preload_post_log(posts)
          return posts
        end
      })
      self.posts, self.next_page_id = self.pager:get_page(opts and opts.page)
      return true
    end,
    preload_post_log = function(self, posts)
      local Topics
      do
        local _obj_0 = require("community.models")
        Posts, Topics, Categories = _obj_0.Posts, _obj_0.Topics, _obj_0.Categories
      end
      local BrowsingFlow = require("community.flows.browsing")
      preload(posts, "user", {
        topic = "category"
      })
      local topics
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #posts do
          local post = posts[_index_0]
          _accum_0[_len_0] = post:get_topic()
          _len_0 = _len_0 + 1
        end
        topics = _accum_0
      end
      Topics:preload_bans(topics, self.current_user)
      Categories:preload_bans((function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #topics do
          local t = topics[_index_0]
          _accum_0[_len_0] = t:get_category()
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)(), self.current_user)
      BrowsingFlow(self):preload_topics(topics)
      return true
    end,
    reports = function(self)
      self:load_category()
      local ReportsFlow = require("community.flows.reports")
      return ReportsFlow(self):show_reports(self.category)
    end,
    moderation_logs = function(self)
      self:load_category()
      assert_error(self.category:allowed_to_moderate(self.current_user), "invalid category")
      local children = self.category:get_flat_children()
      local category_ids
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #children do
          local c = children[_index_0]
          _accum_0[_len_0] = c.id
          _len_0 = _len_0 + 1
        end
        category_ids = _accum_0
      end
      table.insert(category_ids, self.category.id)
      assert_page(self)
      local ModerationLogs
      ModerationLogs = require("community.models").ModerationLogs
      self.pager = ModerationLogs:paginated("\n      where category_id in ? order by id desc\n    ", db.list(category_ids), {
        per_page = 50,
        prepare_results = function(logs)
          preload(logs, "object", "user", {
            log_objects = "object"
          })
          return logs
        end
      })
      self.moderation_logs = self.pager:get_page(self.page)
    end,
    pending_posts = function(self)
      self:load_category()
      assert_error(self.category:allowed_to_moderate(self.current_user), "invalid category")
      local PendingPosts, Topics
      do
        local _obj_0 = require("community.models")
        PendingPosts, Topics, Posts = _obj_0.PendingPosts, _obj_0.Topics, _obj_0.Posts
      end
      assert_valid(self.params, {
        {
          "status",
          optional = true,
          one_of = PendingPosts.statuses
        }
      })
      assert_page(self)
      local status = PendingPosts.statuses:for_db(self.params.status or "pending")
      self.pager = PendingPosts:paginated("\n      where category_id = ? and status = ?\n      order by id asc\n    ", self.category.id, status, {
        prepare_results = function(pending)
          preload(pending, "category", "user", "topic", "parent_post")
          return pending
        end
      })
      self.pending_posts = self.pager:get_page(self.page)
      return self.pending_posts
    end,
    edit_pending_post = function(self)
      local PendingPosts
      PendingPosts = require("community.models").PendingPosts
      self:load_category()
      assert_valid(self.params, {
        {
          "pending_post_id",
          is_integer = true
        },
        {
          "action",
          one_of = {
            "promote",
            "deleted",
            "spam"
          }
        }
      })
      self.pending_post = PendingPosts:find(self.params.pending_post_id)
      assert_error(self.pending_post, "invalid pending post")
      local category_id = self.pending_post.category_id or self.pending_post:get_topic().category_id
      assert_error(category_id == self.category.id, "invalid pending post for category")
      assert_error(self.pending_post:allowed_to_moderate(self.current_user), "invalid pending post")
      local _exp_0 = self.params.action
      if "promote" == _exp_0 then
        self.post = self.pending_post:promote()
      elseif "deleted" == _exp_0 or "spam" == _exp_0 then
        self.post = self.pending_post:update({
          status = PendingPosts.statuses:for_db(self.params.action)
        })
      end
      return true, self.post
    end,
    validate_params = function(self)
      self.params.category = self.params.category or { }
      assert_valid(self.params, {
        {
          "category",
          type = "table"
        }
      })
      local has_field
      do
        local _tbl_0 = { }
        for k in pairs(self.params.category) do
          _tbl_0[k] = true
        end
        has_field = _tbl_0
      end
      local category_params = trim_filter(self.params.category, {
        "title",
        "membership_type",
        "topic_posting_type",
        "voting_type",
        "description",
        "short_description",
        "archived",
        "hidden",
        "rules",
        "type"
      })
      assert_valid(category_params, (function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #VALIDATIONS do
          local v = VALIDATIONS[_index_0]
          if has_field[v] then
            _accum_0[_len_0] = v
            _len_0 = _len_0 + 1
          end
        end
        return _accum_0
      end)())
      if has_field.archived or has_field.update_archived then
        category_params.archived = not not category_params.archived
      end
      if has_field.hidden or has_field.update_hidden then
        category_params.hidden = not not category_params.hidden
      end
      if has_field.membership_type then
        category_params.membership_type = Categories.membership_types:for_db(category_params.membership_type)
      end
      if has_field.voting_type then
        category_params.voting_type = Categories.voting_types:for_db(category_params.voting_type)
      end
      if has_field.topic_posting_type then
        category_params.topic_posting_type = Categories.topic_posting_types:for_db(category_params.topic_posting_type)
      end
      if has_field.title then
        category_params.slug = slugify(category_params.title)
      end
      if has_field.description then
        category_params.description = category_params.description or db.NULL
      end
      if has_field.short_description then
        category_params.short_description = category_params.short_description or db.NULL
      end
      if has_field.rules then
        category_params.rules = category_params.rules or db.NULL
      end
      if has_field.type then
        if self.category then
          assert_error(not self.category.parent_category_id, "only root category can have type set")
        end
        assert_valid(category_params, {
          {
            "type",
            one_of = {
              "directory",
              "post_list"
            }
          }
        })
        category_params.directory = category_params.type == "directory"
        category_params.type = nil
      end
      return category_params
    end,
    new_category = require_login(function(self)
      local create_params = self:validate_params()
      create_params.user_id = self.current_user.id
      self.category = Categories:create(create_params)
      ActivityLogs:create({
        user_id = self.current_user.id,
        object = self.category,
        action = "create"
      })
      return true
    end),
    set_tags = require_login(function(self)
      self:load_category()
      assert_error(self.category:allowed_to_edit(self.current_user), "invalid category")
      local convert_arrays
      convert_arrays = require("community.helpers.app").convert_arrays
      convert_arrays(self.params)
      self.params.category_tags = self.params.category_tags or { }
      assert_valid(self.params, {
        {
          "category_tags",
          type = "table"
        }
      })
      local _list_0 = self.params.category_tags
      for _index_0 = 1, #_list_0 do
        local tag = _list_0[_index_0]
        trim_filter(tag, {
          "label",
          "id",
          "color"
        })
        assert_valid(tag, {
          {
            "id",
            is_integer = true,
            optional = true
          },
          {
            "label",
            exists = "true",
            type = "string",
            max_length = limits.MAX_TAG_LEN,
            "topic tag must be at most " .. tostring(limits.MAX_TAG_LEN) .. " charcaters"
          },
          {
            "color",
            is_color = true,
            optional = true
          }
        })
      end
      local existing_tags = self.category:get_tags()
      local existing_by_id
      do
        local _tbl_0 = { }
        for _index_0 = 1, #existing_tags do
          local t = existing_tags[_index_0]
          _tbl_0[t.id] = t
        end
        existing_by_id = _tbl_0
      end
      local CategoryTags
      CategoryTags = require("community.models").CategoryTags
      local actions = { }
      local used_slugs = { }
      for position, tag in ipairs(self.params.category_tags) do
        local _continue_0 = false
        repeat
          local slug = CategoryTags:slugify(tag.label)
          if slug == "" then
            _continue_0 = true
            break
          end
          if used_slugs[slug] then
            _continue_0 = true
            break
          end
          used_slugs[slug] = true
          local opts = {
            label = tag.label,
            color = tag.color or db.NULL,
            tag_order = position
          }
          do
            local tid = tonumber(tag.id)
            if tid then
              local existing = existing_by_id[tid]
              if not (existing) then
                _continue_0 = true
                break
              end
              existing_by_id[tid] = nil
              opts.slug = slug
              if slug == opts.label then
                opts.label = db.NULL
              end
              table.insert(actions, function()
                return existing:update(filter_update(existing, opts))
              end)
            else
              opts.category_id = self.category.id
              table.insert(actions, function()
                return CategoryTags:create(opts)
              end)
            end
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      for _, old in pairs(existing_by_id) do
        old:delete()
      end
      for _index_0 = 1, #actions do
        local a = actions[_index_0]
        a()
      end
      return true
    end),
    set_children = require_login(function(self)
      self:load_category()
      assert_error(self.category:allowed_to_edit(self.current_user), "invalid category")
      local convert_arrays
      convert_arrays = require("community.helpers.app").convert_arrays
      self.params.categories = self.params.categories or { }
      assert_valid(self.params, {
        {
          "categories",
          type = "table"
        }
      })
      convert_arrays(self.params)
      local assert_categores_length
      assert_categores_length = function(categories)
        return assert_error(#categories <= limits.MAX_CATEGORY_CHILDREN, "category can have at most " .. tostring(limits.MAX_CATEGORY_CHILDREN) .. " children")
      end
      local validate_category_params
      validate_category_params = function(params, depth)
        if depth == nil then
          depth = 1
        end
        assert_error(depth <= limits.MAX_CATEGORY_DEPTH, "category depth must be at most " .. tostring(limits.MAX_CATEGORY_DEPTH))
        assert_valid(params, {
          {
            "id",
            optional = true,
            is_integer = true
          },
          {
            "title",
            exists = true,
            max_length = limits.MAX_TITLE_LEN
          },
          {
            "short_description",
            optional = true,
            max_length = limits.MAX_TITLE_LEN
          },
          {
            "hidden",
            optional = true,
            type = "string"
          },
          {
            "archived",
            optional = true,
            type = "string"
          },
          {
            "directory",
            optional = true,
            type = "string"
          },
          {
            "children",
            optional = true,
            type = "table"
          }
        })
        if params.children then
          assert_categores_length(params.children)
          local _list_0 = params.children
          for _index_0 = 1, #_list_0 do
            local child = _list_0[_index_0]
            validate_category_params(child, depth + 1)
          end
        end
      end
      assert_categores_length(self.params.categories)
      local initial_depth = #self.category:get_ancestors() + 1
      local _list_0 = self.params.categories
      for _index_0 = 1, #_list_0 do
        local category = _list_0[_index_0]
        validate_category_params(category, initial_depth)
      end
      local existing = self.category:get_flat_children()
      local existing_by_id
      do
        local _tbl_0 = { }
        for _index_0 = 1, #existing do
          local c = existing[_index_0]
          _tbl_0[c.id] = c
        end
        existing_by_id = _tbl_0
      end
      local existing_assigned = { }
      local set_children
      set_children = function(parent, children)
        local filtered
        do
          local _accum_0 = { }
          local _len_0 = 1
          for _index_0 = 1, #children do
            local _continue_0 = false
            repeat
              local c = children[_index_0]
              if c.id then
                c.category = existing_by_id[tonumber(c.id)]
                if not (c.category) then
                  _continue_0 = true
                  break
                end
              end
              local _value_0 = c
              _accum_0[_len_0] = _value_0
              _len_0 = _len_0 + 1
              _continue_0 = true
            until true
            if not _continue_0 then
              break
            end
          end
          filtered = _accum_0
        end
        for position, c in ipairs(filtered) do
          local update_params = {
            position = position,
            parent_category_id = parent.id,
            title = c.title,
            short_description = c.short_description or db.NULL,
            hidden = not not c.hidden,
            archived = not not c.archived,
            directory = not not c.directory
          }
          if c.category then
            existing_assigned[c.category.id] = true
            update_params = filter_update(c.category, update_params)
            if next(update_params) then
              c.category:update(update_params)
            end
          else
            c.category = Categories:create(update_params)
          end
        end
        for _index_0 = 1, #filtered do
          local c = filtered[_index_0]
          if c.children and next(c.children) then
            set_children(c.category, c.children)
          end
        end
      end
      set_children(self.category, self.params.categories)
      local orphans
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #existing do
          local _continue_0 = false
          repeat
            local c = existing[_index_0]
            if existing_assigned[c.id] then
              _continue_0 = true
              break
            end
            local _value_0 = c
            _accum_0[_len_0] = _value_0
            _len_0 = _len_0 + 1
            _continue_0 = true
          until true
          if not _continue_0 then
            break
          end
        end
        orphans = _accum_0
      end
      local archived
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #orphans do
          local _continue_0 = false
          repeat
            local o = orphans[_index_0]
            if o.topics_count > 0 then
              o:update(filter_update(o, {
                archived = true,
                hidden = true,
                parent_category_id = self.category.id,
                position = Categories:next_position(self.category.id)
              }))
              _accum_0[_len_0] = o
            else
              o:delete()
              _continue_0 = true
              break
            end
            _len_0 = _len_0 + 1
            _continue_0 = true
          until true
          if not _continue_0 then
            break
          end
        end
        archived = _accum_0
      end
      return true, archived
    end),
    edit_category = require_login(function(self)
      self:load_category()
      assert_error(self.category:allowed_to_edit(self.current_user), "invalid category")
      local update_params = self:validate_params()
      update_params = filter_update(self.category, update_params)
      self.category:update(update_params)
      self:set_tags()
      if next(update_params) then
        ActivityLogs:create({
          user_id = self.current_user.id,
          object = self.category,
          action = "edit"
        })
      end
      return true
    end)
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "CategoriesFlow",
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
  CategoriesFlow = _class_0
  return _class_0
end
