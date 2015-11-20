local Flow
Flow = require("lapis.flow").Flow
local assert_error
assert_error = require("lapis.application").assert_error
local assert_valid
assert_valid = require("lapis.validate").assert_valid
local trim_filter
trim_filter = require("lapis.util").trim_filter
local Users
Users = require("models").Users
local Bookmarks
Bookmarks = require("community.models").Bookmarks
local BookmarksFlow
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
          one_of = Bookmarks.object_types
        }
      })
      local model = Bookmarks:model_for_object_type(self.params.object_type)
      self.object = model:find(self.params.object_id)
      assert_error(self.object, "invalid ban object")
      self.bookmark = Bookmarks:find({
        object_type = Bookmarks:object_type_for_object(self.object),
        object_id = self.object.id,
        user_id = self.current_user.id
      })
    end,
    save_bookmark = function(self)
      self:load_object()
      assert_error(self.object:allowed_to_view(self.current_user), "invalid object")
      return Bookmarks:create({
        object_type = Bookmarks:object_type_for_object(self.object),
        object_id = self.object.id,
        user_id = self.current_user.id
      })
    end,
    remove_bookmark = function(self)
      self:load_object()
      return self.bookmark:delete()
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, req)
      _class_0.__parent.__init(self, req)
      return assert(self.current_user, "missing current user for bookmarks flow")
    end,
    __base = _base_0,
    __name = "BookmarksFlow",
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
  BookmarksFlow = _class_0
  return _class_0
end
