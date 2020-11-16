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
local Moderators
Moderators = require("community.models").Moderators
local preload
preload = require("lapis.db.model").preload
local ModeratorsFlow
do
  local _class_0
  local _parent_0 = Flow
  local _base_0 = {
    expose_assigns = true,
    load_object = function(self)
      if self.object then
        return 
      end
      assert_valid(self.params, {
        {
          "object_id",
          is_integer = true
        },
        {
          "object_type",
          one_of = Moderators.object_types
        }
      })
      local model = Moderators:model_for_object_type(self.params.object_type)
      self.object = model:find(self.params.object_id)
      return assert_error(self.object, "invalid moderator object")
    end,
    load_user = function(self, allow_self)
      self:load_object()
      if self.user then
        return 
      end
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
      if not (allow_self) then
        assert_error(not self.current_user or self.current_user.id ~= self.user.id, "you can't chose yourself")
      end
      self.moderator = Moderators:find_for_object_user(self.object, self.user)
    end,
    add_moderator = require_login(function(self)
      self:load_user()
      assert_error(self.object:allowed_to_edit_moderators(self.current_user), "invalid moderatable object")
      assert_error(not self.object:allowed_to_moderate(self.user, true), "already moderator")
      return Moderators:create({
        user_id = self.user.id,
        object = self.object
      })
    end),
    remove_moderator = require_login(function(self)
      self:load_user(true)
      if not (self.moderator and self.moderator.user_id == self.current_user.id) then
        assert_error(self.object:allowed_to_edit_moderators(self.current_user), "invalid moderatable object")
      end
      assert_error(self.moderator, "not a moderator")
      return self.moderator:delete()
    end),
    show_moderators = function(self)
      self:load_object()
      assert_page(self)
      self.pager = Moderators:paginated("\n      where object_type = ? and object_id = ?\n      order by created_at desc, user_id asc\n    ", Moderators:object_type_for_object(self.object), self.object.id, {
        per_page = 20,
        prepare_results = function(moderators)
          preload(moderators, "user")
          return moderators
        end
      })
      self.moderators = self.pager:get_page(self.page)
      return self.moderators
    end,
    get_pending_moderator = function(self)
      if not (self.pending_moderator) then
        self:load_object()
        local mod = Moderators:find_for_object_user(self.object, self.current_user)
        self.pending_moderator = mod and not mod.accepted and mod
      end
      return self.pending_moderator
    end,
    accept_moderator_position = require_login(function(self)
      local mod = assert_error(self:get_pending_moderator(), "invalid moderator")
      mod:update({
        accepted = true
      })
      return true
    end)
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, req, object)
      self.object = object
      return _class_0.__parent.__init(self, req)
    end,
    __base = _base_0,
    __name = "ModeratorsFlow",
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
  ModeratorsFlow = _class_0
  return _class_0
end
