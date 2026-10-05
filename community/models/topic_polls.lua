local db = require("lapis.db")
local date = require("date")
local enum
enum = require("lapis.db.model").enum
local Model
Model = require("community.model").Model
local TopicPolls
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
    delete = function(self)
      if _class_0.__parent.__base.delete(self) then
        local _list_0 = self:get_poll_choices()
        for _index_0 = 1, #_list_0 do
          local choice = _list_0[_index_0]
          choice:delete()
        end
        return true
      end
    end,
    name_for_display = function(self)
      return self.poll_question
    end,
    allowed_to_edit = function(self, user)
      return self:get_topic():allowed_to_edit(user)
    end,
    allowed_to_vote = function(self, user)
      if not (self:is_open()) then
        return nil, "poll is closed"
      end
      return self:get_topic():allowed_to_view(user)
    end,
    is_open = function(self)
      local now = date(true)
      return now >= date(self.start_date) and now < date(self.end_date)
    end,
    has_votes = function(self)
      local PollChoices, PollVotes
      do
        local _obj_0 = require("community.models")
        PollChoices, PollVotes = _obj_0.PollChoices, _obj_0.PollVotes
      end
      local res = PollVotes:select("where poll_choice_id in (select id from " .. tostring(db.escape_identifier(PollChoices:table_name())) .. " where poll_id = ?) limit 1", self.id, {
        fields = "1"
      })
      return next(res) ~= nil
    end,
    total_vote_count = function(self)
      local sum = 0
      local _list_0 = self:get_poll_choices()
      for _index_0 = 1, #_list_0 do
        local choice = _list_0[_index_0]
        sum = sum + choice.vote_count
      end
      return sum
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
      order = "position ASC"
    }
  }
  self.vote_types = enum({
    single = 1,
    multiple = 2
  })
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    opts.vote_type = self.vote_types:for_db(opts.vote_type or "single")
    return _class_0.__parent.create(self, opts)
  end
  self.create_for_topic = function(self, topic, params)
    local PollChoices
    PollChoices = require("community.models").PollChoices
    local limits = require("community.limits")
    local poll = self:create({
      topic_id = topic.id,
      poll_question = params.poll_question,
      description = params.description,
      anonymous = params.anonymous,
      hide_results = params.hide_results,
      vote_type = params.vote_type,
      start_date = params.start_date,
      end_date = params.end_date or db.raw(db.interpolate_query("date_trunc('second', now() AT TIME ZONE 'utc') + ? * interval '1 second'", limits.DEFAULT_POLL_DURATION))
    })
    for idx, choice in ipairs(params.choices) do
      PollChoices:create({
        poll_id = poll.id,
        choice_text = choice.choice_text,
        description = choice.description,
        position = choice.position or idx
      })
    end
    return poll
  end
  self.pending_data = function(self, params)
    local not_null
    not_null = function(v)
      if not (v == db.NULL) then
        return v
      end
    end
    return {
      poll_question = params.poll_question,
      description = not_null(params.description),
      anonymous = params.anonymous,
      hide_results = params.hide_results,
      vote_type = params.vote_type,
      start_date = params.start_date,
      end_date = params.end_date,
      choices = (function()
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = params.choices
        for _index_0 = 1, #_list_0 do
          local c = _list_0[_index_0]
          _accum_0[_len_0] = {
            choice_text = c.choice_text,
            description = not_null(c.description),
            position = c.position
          }
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)()
    }
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  TopicPolls = _class_0
  return _class_0
end
