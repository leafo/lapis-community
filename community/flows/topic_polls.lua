local db = require("lapis.db")
local Flow
Flow = require("lapis.flow").Flow
local limits = require("community.limits")
local assert_error
assert_error = require("lapis.application").assert_error
local assert_valid, with_params
do
  local _obj_0 = require("lapis.validate")
  assert_valid, with_params = _obj_0.assert_valid, _obj_0.with_params
end
local require_current_user
require_current_user = require("community.helpers.app").require_current_user
local shapes = require("community.helpers.shapes")
local types = require("lapis.validate.types")
local TopicPolls
TopicPolls = require("community.models").TopicPolls
local TopicPollsFlow
do
  local _class_0
  local _parent_0 = Flow
  local _base_0 = {
    validate_params_shape = function(self)
      local choice_shape = types.params_shape(self.__class.CHOICE_VALIDATION)
      local unique_ids = types.custom(function(choices)
        local seen = { }
        for _index_0 = 1, #choices do
          local _continue_0 = false
          repeat
            local c = choices[_index_0]
            if not (c.id) then
              _continue_0 = true
              break
            end
            if seen[c.id] then
              return nil, "duplicate choice id"
            end
            seen[c.id] = true
            _continue_0 = true
          until true
          if not _continue_0 then
            break
          end
        end
        return true
      end)
      return types.params_shape({
        {
          "choices",
          shapes.convert_array * types.params_array(choice_shape, {
            length = types.range(1, 20)
          }) * unique_ids
        },
        unpack(self.__class.POLL_VALIDATION)
      })
    end,
    validate_params = function(self)
      return assert_valid(self.params, self:validate_params_shape())
    end,
    vote = require_current_user(with_params({
      {
        "choice_id",
        types.db_id
      },
      {
        "action",
        types.one_of({
          "create",
          "delete"
        })
      },
      {
        "poll_version",
        types.empty + types.db_id
      }
    }, function(self, params)
      local PollChoices, PollVotes
      do
        local _obj_0 = require("community.models")
        PollChoices, PollVotes = _obj_0.PollChoices, _obj_0.PollVotes
      end
      local choice = assert_error(PollChoices:find(params.choice_id), "invalid poll")
      local poll = assert_error(choice:get_poll(), "invalid poll")
      local _exp_0 = params.action
      if "create" == _exp_0 then
        assert_error(poll:is_open(), "poll is closed")
        assert_error(poll:allowed_to_vote(self.current_user), "not allowed to vote")
        assert_error(params.poll_version, "missing poll version")
        assert_error(params.poll_version == poll.version, "this poll has changed since you loaded it, please review it and vote again")
        return assert_error(choice:vote(self.current_user))
      elseif "delete" == _exp_0 then
        assert_error(poll:is_open(), "poll is closed")
        assert_error(poll:allowed_to_vote(self.current_user), "invalid poll")
        local vote = PollVotes:find({
          poll_choice_id = choice.id,
          user_id = self.current_user.id
        })
        if vote then
          vote:delete()
          return true
        else
          return nil, "invalid vote"
        end
      end
    end)),
    content_changes = function(self, poll, params)
      local changes = { }
      if params.poll_question ~= poll.poll_question then
        table.insert(changes, "question")
      end
      if TopicPolls.vote_types:for_db(params.vote_type) ~= poll.vote_type then
        table.insert(changes, "vote type")
      end
      local choices_by_id
      do
        local _tbl_0 = { }
        local _list_0 = params.choices
        for _index_0 = 1, #_list_0 do
          local c = _list_0[_index_0]
          if c.id then
            _tbl_0[c.id] = c
          end
        end
        choices_by_id = _tbl_0
      end
      local _list_0 = poll:get_poll_choices()
      for _index_0 = 1, #_list_0 do
        local _continue_0 = false
        repeat
          local choice = _list_0[_index_0]
          local choice_params = choices_by_id[choice.id]
          if not (choice_params) then
            table.insert(changes, "removed choice")
            _continue_0 = true
            break
          end
          if choice_params.choice_text ~= choice.choice_text then
            table.insert(changes, "choice text")
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      local _list_1 = params.choices
      for _index_0 = 1, #_list_1 do
        local c = _list_1[_index_0]
        if not (c.id) then
          table.insert(changes, "added choice")
          break
        end
      end
      return changes
    end,
    locked_poll_changes = function(self, poll, params)
      if not (poll:has_votes()) then
        return nil
      end
      local changes
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = self:content_changes(poll, params)
        for _index_0 = 1, #_list_0 do
          local c = _list_0[_index_0]
          if c ~= "added choice" then
            _accum_0[_len_0] = c
            _len_0 = _len_0 + 1
          end
        end
        changes = _accum_0
      end
      if poll.anonymous and not params.anonymous then
        table.insert(changes, "anonymous")
      end
      if next(changes) then
        return changes
      end
    end,
    set_poll = function(self, topic, params)
      TopicPolls = require("community.models").TopicPolls
      local poll_params = {
        poll_question = params.poll_question,
        description = params.description,
        anonymous = params.anonymous,
        hide_results = params.hide_results,
        vote_type = params.vote_type
      }
      local poll
      do
        local existing_poll = topic:get_poll()
        if existing_poll then
          local filter_update
          filter_update = require("community.helpers.models").filter_update
          local poll_update = filter_update(existing_poll, poll_params)
          if next(self:content_changes(existing_poll, params)) then
            poll_update.version = db.raw("version + 1")
          end
          existing_poll:update(poll_update)
          poll = existing_poll
        else
          poll_params.topic_id = topic.id
          poll_params.end_date = db.raw("date_trunc('second', now() AT TIME ZONE 'utc' + interval '1 day' )")
          poll = TopicPolls:create(poll_params)
        end
      end
      if poll then
        self:set_choices(poll, params.choices)
        return poll
      end
    end,
    set_choices = function(self, poll, choices)
      assert(poll, "missing poll id")
      local PollChoices
      PollChoices = require("community.models").PollChoices
      local existing_choices = poll:get_poll_choices()
      local existing_choices_map
      do
        local _tbl_0 = { }
        for _index_0 = 1, #existing_choices do
          local choice = existing_choices[_index_0]
          _tbl_0[choice.id] = choice
        end
        existing_choices_map = _tbl_0
      end
      for idx, choice_params in ipairs(choices) do
        local _continue_0 = false
        repeat
          choice_params.position = choice_params.position or idx
          if choice_params.id then
            local existing_choice = existing_choices_map[choice_params.id]
            if existing_choice then
              existing_choice:update({
                choice_text = choice_params.choice_text,
                description = choice_params.description,
                position = choice_params.position
              })
              existing_choices_map[choice_params.id] = nil
            else
              _continue_0 = true
              break
            end
          else
            PollChoices:create({
              poll_id = poll.id,
              choice_text = choice_params.choice_text,
              description = choice_params.description,
              position = choice_params.position
            })
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      for _, choice in pairs(existing_choices_map) do
        choice:delete()
      end
      return true
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "TopicPollsFlow",
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
  self.POLL_VALIDATION = {
    {
      "poll_question",
      types.limited_text(limits.MAX_TITLE_LEN)
    },
    {
      "description",
      types.empty / db.NULL + types.limited_text(limits.MAX_TITLE_LEN)
    },
    {
      "anonymous",
      types.empty / false + types.any / true
    },
    {
      "hide_results",
      types.empty / false + types.any / true
    },
    {
      "vote_type",
      shapes.default("single") * types.db_enum(TopicPolls.vote_types)
    }
  }
  self.CHOICE_VALIDATION = {
    {
      "id",
      types.db_id + types.empty
    },
    {
      "choice_text",
      types.limited_text(limits.MAX_TITLE_LEN)
    },
    {
      "description",
      types.empty / db.NULL + types.limited_text(limits.MAX_TITLE_LEN)
    },
    {
      "position",
      types.empty + types.db_id
    }
  }
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  TopicPollsFlow = _class_0
  return _class_0
end
