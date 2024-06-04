local db = require("lapis.db")
local Model
Model = require("community.model").Model
local PollVotes
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
    create = function(self, opts)
      if opts == nil then
        opts = { }
      end
      local res = db.insert(self.__class:table_name(), opts, {
        on_conflict = "do nothing",
        returning = "*"
      })
      if res.counted then
        local PollChoices
        PollChoices = require("community.models").PollChoices
        db.update(PollChoices:table_name(), {
          vote_count = db.raw(db.interpolate_query("vote_count + 1"))
        }, db.clause({
          {
            "poll_id = ?",
            res.poll_id
          }
        }))
      end
      return self:load(res)
    end,
    set_counted = function(self, counted)
      local updated = self:update({
        counted = counted
      }, {
        where = db.clause({
          {
            "counted = ?",
            counted
          }
        })
      })
      if updated then
        local delta
        if counted then
          delta = 1
        else
          delta = -1
        end
        db.update(self.poll_choice:table_name(), {
          vote_count = db.raw(db.interpolate_query("vote_count + ?", delta))
        }, db.clause({
          {
            "poll_id = ?",
            self.poll_id
          }
        }))
        return true
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "PollVotes",
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
  self.timestamp = true
  self.relations = {
    {
      "poll_choice",
      belongs_to = "PollChoices"
    },
    {
      "user",
      belongs_to = "Users"
    }
  }
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  PollVotes = _class_0
  return _class_0
end
