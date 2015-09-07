local Flow
Flow = require("lapis.flow").Flow
local Users
Users = require("models").Users
local Categories, CategoryMembers, ActivityLogs
do
  local _obj_0 = require("community.models")
  Categories, CategoryMembers, ActivityLogs = _obj_0.Categories, _obj_0.CategoryMembers, _obj_0.ActivityLogs
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
local limits = require("community.limits")
local db = require("lapis.db")
local CategoriesFlow
do
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
      assert_error(self.category, "invalid category")
      return assert_error(self.category:allowed_to_view(self.current_user), "invalid category")
    end,
    reports = function(self)
      self:load_category()
      local ReportsFlow = require("community.flows.reports")
      return ReportsFlow(self):show_reports(self.category)
    end,
    moderation_logs = function(self)
      self:load_category()
      assert_error(self.category:allowed_to_moderate(self.current_user), "invalid category")
      assert_page(self)
      local ModerationLogs
      ModerationLogs = require("community.models").ModerationLogs
      self.pager = ModerationLogs:paginated("\n      where category_id = ? order by id desc\n    ", self.category.id, {
        prepare_results = function(logs)
          ModerationLogs:preload_objects(logs)
          Users:include_in(logs, "user_id")
          return logs
        end
      })
      self.moderation_logs = self.pager:get_page(self.page)
    end,
    validate_params = function(self)
      assert_valid(self.params, {
        {
          "category",
          type = "table"
        }
      })
      local category_params = trim_filter(self.params.category, {
        "title",
        "membership_type",
        "voting_type",
        "description",
        "short_description",
        "archived",
        "hidden",
        "rules"
      })
      assert_valid(category_params, {
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
      })
      category_params.archived = not not category_params.archived
      category_params.hidden = not not category_params.hidden
      category_params.membership_type = Categories.membership_types:for_db(category_params.membership_type)
      category_params.voting_type = Categories.voting_types:for_db(category_params.voting_type)
      category_params.slug = slugify(category_params.title)
      category_params.description = category_params.description or db.NULL
      category_params.short_description = category_params.short_description or db.NULL
      category_params.rules = category_params.rules or db.NULL
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
    edit_category = require_login(function(self)
      self:load_category()
      assert_error(self.category:allowed_to_edit(self.current_user), "invalid category")
      local update_params = self:validate_params()
      update_params = filter_update(self.category, update_params)
      self.category:update(update_params)
      ActivityLogs:create({
        user_id = self.current_user.id,
        object = self.category,
        action = "edit"
      })
      return true
    end)
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  local _class_0 = setmetatable({
    __init = function(self, ...)
      return _parent_0.__init(self, ...)
    end,
    __base = _base_0,
    __name = "CategoriesFlow",
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
  CategoriesFlow = _class_0
  return _class_0
end