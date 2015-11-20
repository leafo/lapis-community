local Flow
Flow = require("lapis.flow").Flow
local Votes, CommunityUsers
do
  local _obj_0 = require("community.models")
  Votes, CommunityUsers = _obj_0.Votes, _obj_0.CommunityUsers
end
local db = require("lapis.db")
local assert_error
assert_error = require("lapis.application").assert_error
local assert_valid
assert_valid = require("lapis.validate").assert_valid
local require_login
require_login = require("community.helpers.app").require_login
local VotesFlow
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
          one_of = Votes.object_types
        }
      })
      local model = Votes:model_for_object_type(self.params.object_type)
      self.object = model:find(self.params.object_id)
      return assert_error(self.object, "invalid vote object")
    end,
    vote = require_login(function(self)
      self:load_object()
      if self.params.action then
        assert_valid(self.params, {
          {
            "action",
            one_of = {
              "remove"
            }
          }
        })
        local _exp_0 = self.params.action
        if "remove" == _exp_0 then
          assert_error(self.object:allowed_to_vote(self.current_user, "remove"), "not allowed to unvote")
          if Votes:unvote(self.object, self.current_user) then
            CommunityUsers:for_user(self.current_user):increment("votes_count", -1)
          end
        end
      else
        assert_valid(self.params, {
          {
            "direction",
            one_of = {
              "up",
              "down"
            }
          }
        })
        assert_error(self.object:allowed_to_vote(self.current_user, self.params.direction), "not allowed to vote")
        local action
        action, self.vote = Votes:vote(self.object, self.current_user, self.params.direction == "up")
        if action == "insert" then
          CommunityUsers:for_user(self.current_user):increment("votes_count")
        end
      end
      return true
    end)
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "VotesFlow",
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
  VotesFlow = _class_0
  return _class_0
end
