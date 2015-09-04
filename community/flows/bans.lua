local Flow
Flow = require("lapis.flow").Flow
local assert_error
assert_error = require("lapis.application").assert_error
local assert_valid
assert_valid = require("lapis.validate").assert_valid
local trim_filter
trim_filter = require("lapis.util").trim_filter
local assert_page, require_login
do
  local _obj_0 = require("community.helpers.app")
  assert_page, require_login = _obj_0.assert_page, _obj_0.require_login
end
local Users
Users = require("models").Users
local Bans, Categories, Topics
do
  local _obj_0 = require("community.models")
  Bans, Categories, Topics = _obj_0.Bans, _obj_0.Categories, _obj_0.Topics
end
local BansFlow
do
  local _parent_0 = Flow
  local _base_0 = {
    expose_assigns = true,
    load_banned_user = function(self)
      assert_valid(self.params, {
        {
          "banned_user_id",
          is_integer = true
        }
      })
      self.banned = assert_error(Users:find(self.params.banned_user_id), "invalid user")
      return assert_error(self.banned.id ~= self.current_user.id, "you can not ban yourself")
    end,
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
          one_of = Bans.object_types
        }
      })
      local model = Bans:model_for_object_type(self.params.object_type)
      self.object = model:find(self.params.object_id)
      assert_error(self.object, "invalid ban object")
      return assert_error(self.object:allowed_to_moderate(self.current_user), "invalid permissions")
    end,
    load_ban = function(self)
      if self.ban ~= nil then
        return 
      end
      self:load_banned_user()
      self:load_object()
      self.ban = Bans:find({
        object_type = Bans:object_type_for_object(self.object),
        object_id = self.object.id,
        banned_user_id = self.banned.id
      })
      self.ban = self.ban or false
    end,
    write_moderation_log = function(self, action, reason, log_objects)
      self:load_object()
      local ModerationLogs
      ModerationLogs = require("community.models").ModerationLogs
      local category_id
      local _exp_0 = Bans:object_type_for_object(self.object)
      if Bans.object_types.category == _exp_0 then
        category_id = self.object.id
      elseif Bans.object_types.topic == _exp_0 then
        category_id = self.object.category_id
      else
        category_id = error("no category id for ban moderation log")
      end
      return ModerationLogs:create({
        user_id = self.current_user.id,
        object = self.object,
        category_id = category_id,
        action = action,
        reason = reason,
        log_objects = log_objects
      })
    end,
    create_ban = function(self)
      self:load_banned_user()
      self:load_object()
      trim_filter(self.params)
      assert_valid(self.params, {
        {
          "reason",
          exists = true
        }
      })
      local ban = Bans:create({
        object = self.object,
        reason = self.params.reason,
        banned_user_id = self.banned.id,
        banning_user_id = self.current_user.id
      })
      if ban then
        self:write_moderation_log(tostring(self.params.object_type) .. ".ban", self.params.reason, {
          self.banned
        })
      end
      return true
    end,
    delete_ban = function(self)
      self:load_ban()
      assert_error(self.ban, "invalid ban")
      if self.ban and self.ban:delete() then
        self:write_moderation_log(tostring(self.params.object_type) .. ".unban", nil, {
          self.banned
        })
      end
      return true
    end,
    show_bans = function(self)
      self:load_object()
      assert_page(self)
      self.pager = Bans:paginated([[      where object_type = ? and object_id = ?
      order by created_at desc
    ]], Bans:object_type_for_object(self.object), self.object.id, {
        per_page = 20,
        prepare_results = function(bans)
          Users:include_in(bans, "banned_user_id")
          Users:include_in(bans, "banning_user_id")
          return bans
        end
      })
      self.bans = self.pager:get_page(self.page)
      return self.bans
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  local _class_0 = setmetatable({
    __init = function(self, req, object)
      self.object = object
      _parent_0.__init(self, req)
      return assert(self.current_user, "missing current user for bans flow")
    end,
    __base = _base_0,
    __name = "BansFlow",
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
  BansFlow = _class_0
  return _class_0
end
