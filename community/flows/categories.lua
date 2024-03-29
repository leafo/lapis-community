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
local slugify
slugify = require("lapis.util").slugify
local assert_page, require_current_user
do
  local _obj_0 = require("community.helpers.app")
  assert_page, require_current_user = _obj_0.assert_page, _obj_0.require_current_user
end
local filter_update
filter_update = require("community.helpers.models").filter_update
local preload
preload = require("lapis.db.model").preload
local limits = require("community.limits")
local db = require("lapis.db")
local shapes = require("community.helpers.shapes")
local types = require("lapis.validate.types")
local split_field
split_field = function(fields, name)
  if fields then
    for _index_0 = 1, #fields do
      local f = fields[_index_0]
      if f == name then
        return true, (function()
          local _accum_0 = { }
          local _len_0 = 1
          for _index_1 = 1, #fields do
            local ff = fields[_index_1]
            if ff ~= name then
              _accum_0[_len_0] = ff
              _len_0 = _len_0 + 1
            end
          end
          return _accum_0
        end)()
      end
    end
    local _ = false, fields
  end
  return true, fields
end
local nullable_html
nullable_html = function(t)
  return shapes.empty_html / db.NULL + t
end
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
      return MembersFlow(self)
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
      local params = assert_valid(self.params, types.params_shape({
        {
          "category_id",
          types.db_id
        }
      }))
      self.category = Categories:find(params.category_id)
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
      local params = assert_valid(self.params, types.params_shape({
        {
          "status",
          shapes.default("pending") * types.db_enum(PendingPosts.statuses)
        }
      }))
      assert_page(self)
      self.pager = PendingPosts:paginated("\n      where ?\n      order by id asc\n    ", db.clause({
        category_id = self.category.id,
        status = params.status
      }), {
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
      local params = assert_valid(self.params, types.params_shape({
        {
          "pending_post_id",
          types.db_id
        },
        {
          "action",
          types.one_of({
            "promote",
            "deleted",
            "spam"
          })
        }
      }))
      self.pending_post = PendingPosts:find(params.pending_post_id)
      assert_error(self.pending_post, "invalid pending post")
      local category_id = self.pending_post.category_id or self.pending_post:get_topic().category_id
      assert_error(category_id == self.category.id, "invalid pending post for category")
      assert_error(self.pending_post:allowed_to_moderate(self.current_user), "invalid pending post")
      local _exp_0 = params.action
      if "promote" == _exp_0 then
        self.post = self.pending_post:promote(self)
      elseif "deleted" == _exp_0 or "spam" == _exp_0 then
        self.post = self.pending_post:update({
          status = PendingPosts.statuses:for_db(params.action)
        })
      end
      return true, self.post
    end,
    validate_params = function(self, fields_list)
      local validation
      if fields_list then
        local out
        do
          local _accum_0 = { }
          local _len_0 = 1
          for _index_0 = 1, #fields_list do
            local field = fields_list[_index_0]
            local found
            local _list_0 = self.__class.CATEGORY_VALIDATION
            for _index_1 = 1, #_list_0 do
              local v = _list_0[_index_1]
              if v[1] == field then
                found = v
                break
              end
            end
            if not (found) then
              error("tried to validate for invalid field: " .. tostring(field))
            end
            local _value_0 = found
            _accum_0[_len_0] = _value_0
            _len_0 = _len_0 + 1
          end
          out = _accum_0
        end
        if not (next(out)) then
          error("no fields to validate")
        end
        validation = out
      else
        validation = self.__class.CATEGORY_VALIDATION
      end
      local params = assert_valid(self.params.category or { }, types.params_shape(validation))
      if params.type then
        if self.category then
          assert_error(not self.category.parent_category_id, "only root category can have type set")
        end
        params.directory = params.type == "directory"
        params.type = nil
      end
      if params.title then
        params.slug = slugify(params.title)
      end
      return params
    end,
    new_category = require_current_user(function(self, ...)
      local create_params = self:validate_params(...)
      create_params.user_id = self.current_user.id
      self.category = Categories:create(create_params)
      ActivityLogs:create({
        user_id = self.current_user.id,
        object = self.category,
        action = "create"
      })
      return self.category
    end),
    set_tags = require_current_user(function(self)
      self:load_category()
      assert_error(self.category:allowed_to_edit(self.current_user), "invalid category")
      local category_tags
      category_tags = assert_valid(self.params, types.params_shape({
        {
          "category_tags",
          shapes.default(function()
            return { }
          end) * shapes.convert_array
        }
      })).category_tags
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
      local made_change = false
      for position, tag_params in ipairs(category_tags) do
        local _continue_0 = false
        repeat
          local tag = assert_valid(tag_params, types.params_shape(self.__class.TAG_VALIDATION, {
            error_prefix = "topic tag " .. tostring(position)
          }))
          tag.tag_order = position
          tag.slug = CategoryTags:slugify(tag.label)
          if not (tag.slug) then
            _continue_0 = true
            break
          end
          if used_slugs[tag.slug] then
            _continue_0 = true
            break
          end
          used_slugs[tag.slug] = true
          if tag.id then
            local existing = existing_by_id[tag.id]
            if not (existing) then
              _continue_0 = true
              break
            end
            existing_by_id[tag.id] = nil
            tag.id = nil
            if tag.slug == tag.label then
              tag.label = db.NULL
            end
            table.insert(actions, function()
              if existing:update(filter_update(existing, tag)) then
                made_change = true
              end
            end)
          else
            tag.category_id = self.category.id
            table.insert(actions, function()
              CategoryTags:create(tag)
              made_change = true
            end)
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      for _, old in pairs(existing_by_id) do
        if old:delete() then
          made_change = true
        end
      end
      for _index_0 = 1, #actions do
        local a = actions[_index_0]
        a()
      end
      return made_change
    end),
    set_children = require_current_user(function(self)
      self:load_category()
      assert_error(self.category:allowed_to_edit(self.current_user), "invalid category")
      local convert_children
      convert_children = types.array_of(types.partial({
        children = types.empty + shapes.convert_array * types.proxy(function()
          return convert_children
        end)
      }))
      local params = assert_valid(self.params, types.params_shape({
        {
          "categories",
          shapes.default(function()
            return { }
          end) * shapes.convert_array * convert_children
        }
      }))
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
        local out = assert_valid(params, types.params_shape(self.__class.CATEGORY_CHILD_VALIDATION))
        if out.children then
          assert_categores_length(out.children)
          do
            local _accum_0 = { }
            local _len_0 = 1
            local _list_0 = out.children
            for _index_0 = 1, #_list_0 do
              local child = _list_0[_index_0]
              _accum_0[_len_0] = validate_category_params(child, depth + 1)
              _len_0 = _len_0 + 1
            end
            out.children = _accum_0
          end
        end
        return out
      end
      assert_categores_length(params.categories)
      local initial_depth = #self.category:get_ancestors() + 1
      local categories
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = params.categories
        for _index_0 = 1, #_list_0 do
          local category = _list_0[_index_0]
          _accum_0[_len_0] = validate_category_params(category, initial_depth)
          _len_0 = _len_0 + 1
        end
        categories = _accum_0
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
            short_description = c.short_description,
            hidden = c.hidden,
            archived = c.archived,
            directory = c.directory
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
      set_children(self.category, categories)
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
      local to_delete = { }
      local archived = { }
      for _index_0 = 1, #orphans do
        local _continue_0 = false
        repeat
          local o = orphans[_index_0]
          if o.topics_count > 0 then
            table.insert(archived, o)
            o:update(filter_update(o, {
              archived = true,
              hidden = true,
              parent_category_id = self.category.id,
              position = Categories:next_position(self.category.id)
            }))
          else
            table.insert(to_delete, o)
            _continue_0 = true
            break
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      for _index_0 = 1, #to_delete do
        local cat = to_delete[_index_0]
        cat:delete("hard")
      end
      return true, archived
    end),
    edit_category = require_current_user(function(self, fields_list)
      self:load_category()
      assert_error(self.category:allowed_to_edit(self.current_user), "invalid category")
      local category_updated = false
      local update_tags
      update_tags, fields_list = split_field(fields_list, "category_tags")
      local updated_fields = { }
      if not fields_list or next(fields_list) then
        local update_params = self:validate_params(fields_list)
        update_params = filter_update(self.category, update_params)
        if self.category:update(update_params) then
          for k in pairs(update_params) do
            table.insert(updated_fields, k)
          end
          category_updated = true
        end
      end
      if update_tags then
        if self:set_tags() then
          table.insert(updated_fields, "category_tags")
          category_updated = true
        end
      end
      if category_updated then
        table.sort(updated_fields)
        ActivityLogs:create({
          user_id = self.current_user.id,
          object = self.category,
          action = "edit",
          data = {
            fields = updated_fields
          }
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
  local self = _class_0
  self.CATEGORY_VALIDATION = {
    {
      "title",
      types.limited_text(limits.MAX_TITLE_LEN)
    },
    {
      "short_description",
      shapes.db_nullable(types.limited_text(limits.MAX_TITLE_LEN))
    },
    {
      "description",
      nullable_html(types.limited_text(limits.MAX_BODY_LEN))
    },
    {
      "membership_type",
      shapes.db_nullable(types.db_enum(Categories.membership_types))
    },
    {
      "voting_type",
      shapes.db_nullable(types.db_enum(Categories.voting_types))
    },
    {
      "topic_posting_type",
      shapes.db_nullable(types.db_enum(Categories.topic_posting_types))
    },
    {
      "approval_type",
      shapes.db_nullable(types.db_enum(Categories.approval_types))
    },
    {
      "archived",
      types.empty / false + types.any / true
    },
    {
      "hidden",
      types.empty / false + types.any / true
    },
    {
      "rules",
      nullable_html(types.limited_text(limits.MAX_BODY_LEN))
    },
    {
      "type",
      types.empty + types.one_of({
        "directory",
        "post_list"
      })
    }
  }
  self.TAG_VALIDATION = {
    {
      "id",
      types.db_id + types.empty
    },
    {
      "label",
      types.limited_text(limits.MAX_TAG_LEN)
    },
    {
      "description",
      shapes.db_nullable(types.limited_text(80))
    },
    {
      "color",
      shapes.db_nullable(shapes.color)
    }
  }
  self.CATEGORY_CHILD_VALIDATION = {
    {
      "id",
      types.db_id + types.empty
    },
    {
      "title",
      types.limited_text(limits.MAX_TITLE_LEN)
    },
    {
      "short_description",
      shapes.db_nullable(types.limited_text(limits.MAX_TITLE_LEN))
    },
    {
      "archived",
      types.empty / false + types.any / true
    },
    {
      "hidden",
      types.empty / false + types.any / true
    },
    {
      "directory",
      types.empty / false + types.any / true
    },
    {
      "children",
      types.empty + types.table
    }
  }
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  CategoriesFlow = _class_0
  return _class_0
end
