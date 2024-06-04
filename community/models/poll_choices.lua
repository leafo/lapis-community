local db = require("lapis.db")
local Model
Model = require("community.model").Model
local PollChoices
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
    name_for_display = function(self)
      return self.choice_text
    end,
    recount = function(self)
      local PollVotes
      PollVotes = require("community.models").PollVotes
      return self:update({
        vote_count = db.raw("(select count(*)\n        from " .. tostring(db.escape_identifier(PollVotes:table_name())) .. "\n        where poll_choice_id = " .. tostring(db.escape_identifier(self.__class:table_name())) .. ".id and counted = true)")
      })
    end,
    vote = function(self, user, counted)
      if counted == nil then
        counted = true
      end
      assert(user, "missing user")
      local TopicPolls, PollVotes
      do
        local _obj_0 = require("community.models")
        TopicPolls, PollVotes = _obj_0.TopicPolls, _obj_0.PollVotes
      end
      local poll = self:get_poll()
      if not (poll:is_open()) then
        return nil, "poll is closed"
      end
      local vote = PollVotes:create({
        poll_choice_id = self.id,
        user_id = user.id,
        counted = counted
      })
      if not (vote) then
        return nil, "could not create vote"
      end
      if poll.vote_type == TopicPolls.vote_types.single then
        local other_votes = PollVotes:select(db.clause({
          {
            "user_id = ?",
            user.id
          },
          {
            "poll_choice_id in (select id from " .. tostring(db.escape_identifier(PollChoices:table_name())) .. " where poll_id = ?)",
            poll.id
          },
          {
            "id != ?",
            vote.id
          }
        }))
        for _index_0 = 1, #other_votes do
          local other_vote = other_votes[_index_0]
          other_vote:delete()
        end
      end
      return vote
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "PollChoices",
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
      "poll",
      belongs_to = "TopicPolls"
    },
    {
      "poll_votes",
      has_many = "PollVotes",
      key = "poll_choice_id"
    }
  }
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  PollChoices = _class_0
  return _class_0
end
