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
local Users
Users = require("models").Users
local CategoryMembers
CategoryMembers = require("community.models").CategoryMembers
local MembersFlow
do
  local _class_0
  local _parent_0 = Flow
  local _base_0 = {
    expose_assigns = true,
    load_user = function(self)
      assert_valid(self.params, {
        {
          "user_id",
          optional = true,
          is_integer = true
        },
        {
          "username",
          optional = true
        }
      })
      if self.params.user_id then
        self.user = Users:find(self.params.user_id)
      elseif self.params.username then
        self.user = Users:find({
          username = self.params.username
        })
      end
      assert_error(self.user, "invalid user")
      assert_error(self.current_user.id ~= self.user.id, "can't add self")
      self.member = self.category:find_member(self.user)
    end,
    show_members = function(self)
      assert_page(self)
      self.pager = CategoryMembers:paginated([[      where category_id = ?
      order by created_at desc
    ]], self.category.id, {
        per_page = 20,
        prepare_results = function(members)
          CategoryMembers:preload_relations(members, "user")
          return members
        end
      })
      self.members = self.pager:get_page(self.page)
      return self.members
    end,
    add_member = require_login(function(self)
      assert_error(self.category:allowed_to_edit_members(self.current_user), "invalid category")
      self:load_user()
      assert_error(not self.member, "already a member")
      CategoryMembers:create({
        category_id = self.category.id,
        user_id = self.user.id
      })
      return true
    end),
    remove_member = require_login(function(self)
      assert_error(self.category:allowed_to_edit_members(self.current_user), "invalid category")
      self:load_user()
      assert_error(self.member, "user is not member")
      self.member:delete()
      return true
    end),
    accept_member = require_login(function(self)
      local member = CategoryMembers:find({
        category_id = self.category.id,
        user_id = self.current_user.id,
        accepted = false
      })
      assert_error(member, "no pending membership")
      member:update({
        accepted = true
      })
      return true
    end)
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, req, category_flow)
      self.category_flow = category_flow
      _class_0.__parent.__init(self, req)
      return assert(self.category, "missing category")
    end,
    __base = _base_0,
    __name = "MembersFlow",
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
  MembersFlow = _class_0
  return _class_0
end
