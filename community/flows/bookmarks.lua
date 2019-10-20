local Flow
Flow = require("lapis.flow").Flow
local db = require("lapis.db")
local assert_error
assert_error = require("lapis.application").assert_error
local assert_valid
assert_valid = require("lapis.validate").assert_valid
local Users
Users = require("models").Users
local Bookmarks
Bookmarks = require("community.models").Bookmarks
local require_login, assert_page
do
  local _obj_0 = require("community.helpers.app")
  require_login, assert_page = _obj_0.require_login, _obj_0.assert_page
end
local preload
preload = require("lapis.db.model").preload
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
      assert_error(self.object, "invalid bookmark object")
      self.bookmark = Bookmarks:get(self.object, self.current_user)
    end,
    show_topic_bookmarks = require_login(function(self)
      local BrowsingFlow = require("community.flows.browsing")
      local Topics, Categories
      do
        local _obj_0 = require("community.models")
        Topics, Categories = _obj_0.Topics, _obj_0.Categories
      end
      self.pager = Topics:paginated("\n      where id in (\n        select object_id from " .. tostring(db.escape_identifier(Bookmarks:table_name())) .. "\n        where user_id = ? and object_type = ?\n      )\n      and not deleted\n      order by last_post_id desc\n    ", self.current_user.id, Bookmarks.object_types.topic, {
        per_page = 50,
        prepare_results = function(topics)
          preload(topics, "category")
          Topics:preload_bans(topics, self.current_user)
          local categories
          do
            local _accum_0 = { }
            local _len_0 = 1
            for _index_0 = 1, #topics do
              local t = topics[_index_0]
              _accum_0[_len_0] = t:get_category()
              _len_0 = _len_0 + 1
            end
            categories = _accum_0
          end
          Categories:preload_bans(categories, self.current_user)
          preload(categories, "tags")
          BrowsingFlow(self):preload_topics(topics)
          return topics
        end
      })
      assert_page(self)
      self.topics = self.pager:get_page(self.page)
    end),
    save_bookmark = function(self)
      self:load_object()
      assert_error(self.object:allowed_to_view(self.current_user, self._req), "invalid object")
      return Bookmarks:save(self.object, self.current_user)
    end,
    remove_bookmark = function(self)
      self:load_object()
      return Bookmarks:remove(self.object, self.current_user)
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
