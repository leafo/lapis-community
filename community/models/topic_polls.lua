local db = require("lapis.db")
local date = require("date")
local Model
Model = require("community.model").Model
local TopicPolls
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
    is_open = function(self)
      local now = now(true)
      return now >= date(self.start_date) and now < date(self.end_date)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "TopicPolls",
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
      "topic",
      belongs_to = "Topics"
    },
    {
      "poll_choices",
      has_many = "PollChoices",
      key = "poll_id",
      order = "'order' ASC"
    }
  }
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  TopicPolls = _class_0
  return _class_0
end
