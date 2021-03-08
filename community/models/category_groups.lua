local db = require("lapis.db")
local enum
enum = require("lapis.db.model").enum
local Model
Model = require("community.model").Model
local CategoryGroups
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
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
        local mod = self:find_moderator(user)
        if mod then
          if mod.accepted then
            return true
          end
        end
      end
      return false
    end,
    allowed_to_view = function(self, user, req)
      if self:allowed_to_edit(user) then
        return true
      end
      if self:find_ban(user) then
        return false
      end
      return true
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
    find_ban = function(self, user)
      if not (user) then
        return nil
      end
      local Bans
      Bans = require("community.models").Bans
      return Bans:find_for_object(self, user)
    end,
    find_moderator = function(self, user)
      if not (user) then
        return nil
      end
      local Moderators
      Moderators = require("community.models").Moderators
      return Moderators:find({
        object_type = Moderators.object_types.category_group,
        object_id = self.id,
        user_id = user.id
      })
    end,
    get_categories_paginated = function(self, opts)
      if opts == nil then
        opts = { }
      end
      local Categories, CategoryGroupCategories
      do
        local _obj_0 = require("community.models")
        Categories, CategoryGroupCategories = _obj_0.Categories, _obj_0.CategoryGroupCategories
      end
      local fields = opts.fields
      local prepare_results = opts.prepare_results
      opts.prepare_results = function(cgcs)
        CategoryGroupCategories.relation_preloaders.category(CategoryGroupCategories, cgcs, {
          fields = fields
        })
        local categories
        do
          local _accum_0 = { }
          local _len_0 = 1
          for _index_0 = 1, #cgcs do
            local cgc = cgcs[_index_0]
            _accum_0[_len_0] = cgc.category
            _len_0 = _len_0 + 1
          end
          categories = _accum_0
        end
        if prepare_results then
          prepare_results(categories)
        end
        return categories
      end
      opts.fields = nil
      return self:get_category_group_categories_paginated(opts)
    end,
    set_categories = function(self, categories)
      local Categories
      Categories = require("community.models").Categories
      local to_add = { }
      local ids = self:get_category_group_categories_paginated({
        fields = "category_id"
      }):get_all()
      do
        local _tbl_0 = { }
        for _index_0 = 1, #ids do
          local cgc = ids[_index_0]
          _tbl_0[cgc.category_id] = 1
        end
        ids = _tbl_0
      end
      for _index_0 = 1, #categories do
        local c = categories[_index_0]
        if ids[c.id] then
          local _update_0 = c.id
          ids[_update_0] = ids[_update_0] - 1
        else
          table.insert(to_add, c)
        end
      end
      local to_remove
      do
        local _accum_0 = { }
        local _len_0 = 1
        for id, count in pairs(ids) do
          if count == 1 then
            _accum_0[_len_0] = id
            _len_0 = _len_0 + 1
          end
        end
        to_remove = _accum_0
      end
      to_remove = Categories:find_all(to_remove)
      for _index_0 = 1, #to_remove do
        local category = to_remove[_index_0]
        self:remove_category(category)
      end
      for _index_0 = 1, #to_add do
        local category = to_add[_index_0]
        self:add_category(category)
      end
      return true
    end,
    add_category = function(self, category)
      local CategoryGroupCategories
      CategoryGroupCategories = require("community.models").CategoryGroupCategories
      local group_category = CategoryGroupCategories:create({
        category_id = category.id,
        category_group_id = self.id
      })
      if group_category then
        self:update({
          categories_count = db.raw("categories_count + 1")
        })
        category:update({
          category_groups_count = db.raw("category_groups_count + 1")
        }, {
          timestamp = false
        })
        return true
      end
    end,
    remove_category = function(self, category)
      local CategoryGroupCategories
      CategoryGroupCategories = require("community.models").CategoryGroupCategories
      local group_category = CategoryGroupCategories:find({
        category_id = category.id,
        category_group_id = self.id
      })
      if group_category and group_category:delete() then
        self:update({
          categories_count = db.raw("categories_count - 1")
        })
        category:update({
          category_groups_count = db.raw("category_groups_count - 1")
        }, {
          timestamp = false
        })
        return true
      end
    end,
    notification_target_users = function(self)
      return {
        self:get_user()
      }
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "CategoryGroups",
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
  self.timestamp = true
  self.relations = {
    {
      "moderators",
      has_many = "Moderators",
      key = "object_id",
      where = {
        object_type = 2
      }
    },
    {
      "user",
      belongs_to = "Users"
    },
    {
      "category_group_categories",
      has_many = "CategoryGroupCategories"
    }
  }
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  CategoryGroups = _class_0
  return _class_0
end
