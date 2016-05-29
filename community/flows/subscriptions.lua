local Flow
Flow = require("lapis.flow").Flow
local db = require("lapis.db")
local assert_page
assert_page = require("community.helpers.app").assert_page
local SubscriptionsFlow
do
  local _class_0
  local _parent_0 = Flow
  local _base_0 = {
    expose_assigns = true,
    show_subscriptions = function(self)
      local Subscriptions
      Subscriptions = require("community.models").Subscriptions
      self.pager = Subscriptions:paginated("\n      where user_id = ? and subscribed\n      order by created_at desc\n    ", self.current_user.id, {
        per_page = 50,
        prepare_results = function(subs)
          for _index_0 = 1, #subs do
            local sub = subs[_index_0]
            sub.user = self.current_user
          end
          Subscriptions:preload_relations(subs, "object")
          return subs
        end
      })
      assert_page(self)
      self.subscriptions = self.pager:get_page(self.page)
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
    __name = "SubscriptionsFlow",
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
  SubscriptionsFlow = _class_0
  return _class_0
end
