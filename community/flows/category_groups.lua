local Flow
Flow = require("lapis.flow").Flow
local db = require("lapis.db")
local assert_valid, with_params
do
  local _obj_0 = require("lapis.validate")
  assert_valid, with_params = _obj_0.assert_valid, _obj_0.with_params
end
local assert_error
assert_error = require("lapis.application").assert_error
local require_current_user, assert_page
do
  local _obj_0 = require("community.helpers.app")
  require_current_user, assert_page = _obj_0.require_current_user, _obj_0.assert_page
end
local filter_update
filter_update = require("community.helpers.models").filter_update
local CategoryGroups
CategoryGroups = require("community.models").CategoryGroups
local limits = require("community.limits")
local shapes = require("community.helpers.shapes")
local types = require("lapis.validate.types")
local CategoryGroupsFlow
do
  local _class_0
  local _parent_0 = Flow
  local _base_0 = {
    expose_assigns = true,
    bans_flow = function(self)
      self:load_category_group()
      local BansFlow = require("community.flows.bans")
      return BansFlow(self, self.category_group)
    end,
    load_category_group = function(self)
      if self.category_group then
        return 
      end
      assert_valid(self.params, types.params_shape({
        {
          "category_group_id",
          types.db_id
        }
      }))
      self.category_group = CategoryGroups:find(self.params.category_group_id)
      return assert_error(self.category_group, "invalid group")
    end,
    validate_params = with_params({
      {
        "category_group",
        types.params_shape({
          {
            "title",
            shapes.db_nullable(types.limited_text(limits.MAX_TITLE_LEN))
          },
          {
            "description",
            shapes.db_nullable(types.limited_text(limits.MAX_BODY_LEN))
          },
          {
            "rules",
            shapes.db_nullable(types.limited_text(limits.MAX_BODY_LEN))
          }
        })
      }
    }, function(self, params)
      return params.category_group
    end),
    new_category_group = require_current_user(function(self)
      local create_params = self:validate_params()
      create_params.user_id = self.current_user.id
      self.category_group = CategoryGroups:create(create_params)
      return true
    end),
    edit_category_group = require_current_user(function(self)
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
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "CategoryGroupsFlow",
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
  CategoryGroupsFlow = _class_0
  return _class_0
end
