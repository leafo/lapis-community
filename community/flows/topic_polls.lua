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
local date_format = "%Y-%m-%d %H:%M:%S"
local check_duration
check_duration = function(start, finish)
  local date = require("date")
  local duration = date.diff(finish, start):spanseconds()
  if duration < limits.MIN_POLL_DURATION then
    return nil, "poll must be open for at least " .. tostring(math.floor(limits.MIN_POLL_DURATION / 3600)) .. " hour(s)"
  end
  if duration > limits.MAX_POLL_DURATION then
    return nil, "poll can't be open for more than " .. tostring(math.floor(limits.MAX_POLL_DURATION / 86400)) .. " days"
  end
  return true
end
local TopicPollsFlow
do
  local _class_0
  local _parent_0 = Flow
  local _base_0 = {
    expose_assigns = true,
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
    validate_poll = function(self, params)
      local poll
      poll = assert_valid(params, types.params_shape({
        {
          "poll",
          self:validate_params_shape()
        }
      })).poll
      local filter
      filter = function(text)
        if text == db.NULL then
          return text
        end
        return assert_error(TopicPolls:filter_text(text))
      end
      poll.poll_question = filter(poll.poll_question)
      poll.description = filter(poll.description)
      local _list_0 = poll.choices
      for _index_0 = 1, #_list_0 do
        local choice = _list_0[_index_0]
        choice.choice_text = filter(choice.choice_text)
        choice.description = filter(choice.description)
      end
      return poll
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
      self.choice = assert_error(PollChoices:find(params.choice_id), "invalid poll")
      self.poll = assert_error(self.choice:get_poll(), "invalid poll")
      assert_error(self.poll:is_open(), "poll is closed")
      assert_error(self.poll:allowed_to_vote(self.current_user, self._req), "not allowed to vote")
      local _exp_0 = params.action
      if "create" == _exp_0 then
        assert_error(params.poll_version, "missing poll version")
        assert_error(params.poll_version == self.poll.version, "this poll has changed since you loaded it, please review it and vote again")
        self.vote = assert_error(self.choice:vote(self.current_user))
      elseif "delete" == _exp_0 then
        local vote = assert_error(PollVotes:find({
          poll_choice_id = self.choice.id,
          user_id = self.current_user.id
        }), "invalid vote")
        vote:delete()
      end
      return true
    end)),
    choice_voters = function(self, opts)
      if opts == nil then
        opts = { }
      end
      local PollChoices, PollVotes
      do
        local _obj_0 = require("community.models")
        PollChoices, PollVotes = _obj_0.PollChoices, _obj_0.PollVotes
      end
      local OrderedPaginator
      OrderedPaginator = require("lapis.db.pagination").OrderedPaginator
      local preload
      preload = require("lapis.db.model").preload
      local params = assert_valid(self.params, types.params_shape({
        {
          "choice_id",
          types.db_id
        },
        {
          "before",
          types.empty + types.db_id
        }
      }))
      self.choice = assert_error(PollChoices:find(params.choice_id), "invalid poll")
      self.poll = assert_error(self.choice:get_poll(), "invalid poll")
      assert_error(self.poll:get_topic():allowed_to_view(self.current_user, self._req), "invalid poll")
      assert_error(self.poll:allowed_to_view_voters(self.current_user), "not allowed to view voters")
      local per_page = opts.per_page or limits.POLL_VOTERS_PER_PAGE
      local pager = OrderedPaginator(PollVotes, "id", "where ?", db.clause({
        poll_choice_id = self.choice.id,
        counted = true
      }), {
        per_page = per_page,
        prepare_results = function(votes)
          preload(votes, "user")
          return votes
        end
      })
      self.votes = pager:before(params.before)
      if #self.votes == per_page then
        self.next_page = {
          before = self.votes[#self.votes].id
        }
      end
      return self.votes, self.next_page
    end,
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
          local new_description = choice_params.description
          if new_description == db.NULL then
            new_description = nil
          end
          if new_description ~= choice.description then
            table.insert(changes, "choice description")
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
    validate_choice_ids = function(self, poll, params)
      local existing_ids
      do
        local _tbl_0 = { }
        local _list_0 = poll:get_poll_choices()
        for _index_0 = 1, #_list_0 do
          local c = _list_0[_index_0]
          _tbl_0[c.id] = true
        end
        existing_ids = _tbl_0
      end
      local _list_0 = params.choices
      for _index_0 = 1, #_list_0 do
        local c = _list_0[_index_0]
        if c.id and not existing_ids[c.id] then
          return nil, "invalid poll choice"
        end
      end
      return true
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
    validate_end_date = function(self, params, poll)
      local date = require("date")
      local now = date(true)
      local start, finish
      if poll then
        if not params.end_date or poll:is_closed() then
          params.end_date = nil
          return true
        end
        start = date(poll.start_date)
        finish = date(params.end_date)
        if finish <= now then
          params.end_date = now:fmt(date_format)
          return true
        end
      else
        start = now
        if params.end_date then
          finish = date(params.end_date)
        else
          finish = now:copy():addseconds(limits.DEFAULT_POLL_DURATION)
        end
      end
      local ok, err = check_duration(start, finish)
      if not (ok) then
        return nil, err
      end
      params.end_date = finish:fmt(date_format)
      return true
    end,
    load_poll_for_moderation = function(self)
      local TopicsFlow = require("community.flows.topics")
      local topics_flow = TopicsFlow(self)
      topics_flow:load_topic_for_moderation()
      local poll = assert_error(topics_flow.topic:get_poll(), "topic has no poll")
      return topics_flow, poll
    end,
    close_poll = require_current_user(function(self)
      local TopicsFlow = require("community.flows.topics")
      local topics_flow = TopicsFlow(self)
      topics_flow:load_topic()
      local topic = topics_flow.topic
      local poll = assert_error(topic:get_poll(), "topic has no poll")
      assert_error(poll:allowed_to_edit(self.current_user), "invalid user")
      assert_error(not poll:is_closed(), "poll is already closed")
      local params = assert_valid(self.params, types.params_shape({
        {
          "reason",
          types.empty + types.limited_text(limits.MAX_BODY_LEN)
        }
      }))
      local date = require("date")
      poll:update({
        end_date = date(true):fmt(date_format)
      })
      if self.current_user.id ~= topic.user_id then
        topics_flow:write_moderation_log("topic.close_poll", params.reason)
      end
      return true
    end),
    delete_poll = require_current_user(function(self)
      local topics_flow, poll = self:load_poll_for_moderation()
      local params = assert_valid(self.params, types.params_shape({
        {
          "reason",
          types.empty + types.limited_text(limits.MAX_BODY_LEN)
        }
      }))
      poll:delete()
      topics_flow:write_moderation_log("topic.delete_poll", params.reason)
      return true
    end),
    reset_poll_votes = require_current_user(function(self)
      local topics_flow, poll = self:load_poll_for_moderation()
      local params = assert_valid(self.params, types.params_shape({
        {
          "reason",
          types.empty + types.limited_text(limits.MAX_BODY_LEN)
        }
      }))
      local deleted_count = poll:reset_votes()
      topics_flow:write_moderation_log("topic.reset_poll_votes", params.reason, {
        data = {
          deleted_votes = deleted_count
        }
      })
      return true
    end),
    set_poll = function(self, topic, params)
      local poll_params = {
        poll_question = params.poll_question,
        description = params.description,
        anonymous = params.anonymous,
        hide_results = params.hide_results,
        vote_type = params.vote_type
      }
      do
        local existing_poll = topic:get_poll()
        if existing_poll then
          local filter_update
          filter_update = require("community.helpers.models").filter_update
          local poll_update = filter_update(existing_poll, poll_params)
          if next(self:content_changes(existing_poll, params)) then
            poll_update.version = db.raw("version + 1")
          end
          if params.end_date then
            poll_update.end_date = params.end_date
          end
          existing_poll:update(poll_update)
          self:set_choices(existing_poll, params.choices)
          return existing_poll
        else
          return TopicPolls:create_for_topic(topic, params)
        end
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
      for position, choice_params in ipairs(choices) do
        if choice_params.id then
          local existing_choice = assert(existing_choices_map[choice_params.id], "invalid poll choice")
          existing_choice:update({
            choice_text = choice_params.choice_text,
            description = choice_params.description,
            position = position
          })
          existing_choices_map[choice_params.id] = nil
        else
          PollChoices:create({
            poll_id = poll.id,
            choice_text = choice_params.choice_text,
            description = choice_params.description,
            position = position
          })
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
      "end_date",
      types.empty / nil + shapes.utc_timestamp
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
    }
  }
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  TopicPollsFlow = _class_0
  return _class_0
end
