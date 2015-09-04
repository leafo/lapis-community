local Flow
Flow = require("lapis.flow").Flow
local db = require("lapis.db")
local assert_valid
assert_valid = require("lapis.validate").assert_valid
local assert_error
assert_error = require("lapis.application").assert_error
local assert_page, require_login
do
  local _obj_0 = require("community.helpers.app")
  assert_page, require_login = _obj_0.assert_page, _obj_0.require_login
end
local trim_filter
trim_filter = require("lapis.util").trim_filter
local filter_update
filter_update = require("community.helpers.models").filter_update
local CategoryGroups
CategoryGroups = require("community.models").CategoryGroups
local limits = require("community.limits")
local CategoryGroupsFlow
do
  local _parent_0 = Flow
  local _base_0 = {
    expose_assigns = true,
    load_category_group = function(self)
      if self.category_group then
        return 
      end
      assert_valid(self.params, {
        {
          "category_group_id",
          is_integer = true
        }
      })
      self.category_group = CategoryGroups:find(self.params.category_group_id)
      return assert_error(self.category_group, "invalid group")
    end,
    validate_params = function(self)
      assert_valid(self.params, {
        {
          "category_group",
          type = "table"
        }
      })
      local group_params = trim_filter(self.params.category_group, {
        "title",
        "description",
        "rules"
      })
      assert_valid(group_params, {
        {
          "title",
          optional = true,
          max_length = limits.MAX_TITLE_LEN
        },
        {
          "description",
          optional = true,
          max_length = limits.MAX_BODY_LEN
        },
        {
          "rules",
          optional = true,
          max_length = limits.MAX_BODY_LEN
        }
      })
      group_params.title = group_params.title or db.NULL
      group_params.description = group_params.description or db.NULL
      group_params.rules = group_params.rules or db.NULL
      return group_params
    end,
    new_category_group = require_login(function(self)
      local create_params = self:validate_params()
      create_params.user_id = self.current_user.id
      self.category_group = CategoryGroups:create(create_params)
      return true
    end),
    edit_category_group = require_login(function(self)
      self:load_category_group()
      assert_error(self.category_group:allowed_to_edit(self.current_user), "invalid category group")
      local update_params = self:validate_params()
      update_params = filter_update(self.category_group, update_params)
      self.category_group:update(update_params)
      return true
    end),
    moderators_flow = function(self)
      self:load_category_group()
      local ModeratorsFlow = require("community.flows.moderators")
      return ModeratorsFlow(self, self.category_group)
    end,
    show_categories = function(self)
      self:load_category_group()
      assert_page(self)
      self.pager = self.category_group:get_categories_paginated()
      self.categories = self.pager:get_page(self.page)
      return self.categories
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  local _class_0 = setmetatable({
    __init = function(self, ...)
      return _parent_0.__init(self, ...)
    end,
    __base = _base_0,
    __name = "CategoryGroupsFlow",
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
  CategoryGroupsFlow = _class_0
  return _class_0
end
