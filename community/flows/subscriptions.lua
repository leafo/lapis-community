local Flow
Flow = require("lapis.flow").Flow
local db = require("lapis.db")
local assert_page
assert_page = require("community.helpers.app").assert_page
local assert_valid
assert_valid = require("lapis.validate").assert_valid
local assert_error
assert_error = require("lapis.application").assert_error
local types = require("lapis.validate.types")
local Subscriptions
Subscriptions = require("community.models").Subscriptions
local preload
preload = require("lapis.db.model").preload
local SubscriptionsFlow
do
  local _class_0
  local _parent_0 = Flow
  local _base_0 = {
    expose_assigns = true,
    subscribe_to_topic = function(self, topic)
      assert_error(topic:allowed_to_view(self.current_user, self._req), "invalid topic")
      return topic:subscribe(self.current_user)
    end,
    subscribe_to_category = function(self, category)
      assert_error(category:allowed_to_view(self.current_user, self._req), "invalid category")
      return category:subscribe(self.current_user)
    end,
    find_subscription = function(self)
      if self.subscription then
        return self.subscription
      end
      local params = assert_valid(self.params, types.params_shape({
        {
          "object_id",
          types.db_id
        },
        {
          "object_type",
          types.db_enum(Subscriptions.object_types)
        }
      }))
      self.subscription = Subscriptions:find({
        object_type = Subscriptions.object_types:for_db(params.object_type),
        object_id = params.object_id,
        user_id = self.current_user.id
      })
      return self.subscription
    end,
    show_subscriptions = function(self)
      assert_page(self)
      self.pager = Subscriptions:paginated("where ? order by created_at desc", db.clause({
        user_id = self.current_user.id,
        subscribed = true
      }), {
        per_page = 50,
        prepare_results = function(subs)
          for _index_0 = 1, #subs do
            local sub = subs[_index_0]
            sub.user = self.current_user
          end
          preload(subs, "object")
          return subs
        end
      })
      self.subscriptions = self.pager:get_page(self.page)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, req)
      _class_0.__parent.__init(self, req)
      return assert(self.current_user, "missing current user for subscription flow")
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
