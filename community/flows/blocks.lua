local Flow
Flow = require("lapis.flow").Flow
local Users
Users = require("models").Users
local Blocks
Blocks = require("community.models").Blocks
local assert_error
assert_error = require("lapis.application").assert_error
local assert_valid
assert_valid = require("lapis.validate").assert_valid
local assert_page, require_current_user
do
  local _obj_0 = require("community.helpers.app")
  assert_page, require_current_user = _obj_0.assert_page, _obj_0.require_current_user
end
local preload
preload = require("lapis.db.model").preload
local BlocksFlow
do
  local _class_0
  local _parent_0 = Flow
  local _base_0 = {
    expose_assigns = true,
    show_blocks = function(self)
      assert_page(self)
      self.pager = Blocks:paginated("\n      where blocking_user_id = ?\n      order by created_at desc\n    ", self.current_user.id, {
        per_page = 40,
        prepare_results = function(blocks)
          preload(blocks, "blocked_user")
          return blocks
        end
      })
      self.blocks = self.pager:get_page(self.page)
      return self.blocks
    end,
    load_blocked_user = function(self)
      if self.blocked then
        return 
      end
      assert_valid(self.params, {
        {
          "blocked_user_id",
          is_integer = true
        }
      })
      self.blocked = assert_error(Users:find(self.params.blocked_user_id), "invalid user")
      return assert_error(self.blocked.id ~= self.current_user.id, "you can not block yourself")
    end,
    block_user = function(self)
      self:load_blocked_user()
      Blocks:create({
        blocking_user_id = self.current_user.id,
        blocked_user_id = self.blocked.id
      })
      return true
    end,
    unblock_user = function(self)
      self:load_blocked_user()
      local block = Blocks:find({
        blocking_user_id = self.current_user.id,
        blocked_user_id = self.blocked.id
      })
      return block and block:delete()
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, req)
      _class_0.__parent.__init(self, req)
      return assert(self.current_user, "missing current user for blocks flow")
    end,
    __base = _base_0,
    __name = "BlocksFlow",
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
  BlocksFlow = _class_0
  return _class_0
end
