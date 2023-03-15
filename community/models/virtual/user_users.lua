local VirtualModel
VirtualModel = require("community.model").VirtualModel
local UserUsers
do
  local _class_0
  local _parent_0 = VirtualModel
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "UserUsers",
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
  self.primary_key = {
    "source_user_id",
    "dest_user_id"
  }
  self.relations = {
    {
      "block_given",
      has_one = "Blocks",
      key = {
        blocking_user_id = "source_user_id",
        blocked_user_id = "dest_user_id"
      }
    },
    {
      "block_recieved",
      has_one = "Blocks",
      key = {
        blocking_user_id = "dest_user_id",
        blocked_user_id = "source_user_id"
      }
    }
  }
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  UserUsers = _class_0
  return _class_0
end
