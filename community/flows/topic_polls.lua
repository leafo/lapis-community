local db = require("lapis.db")
local Flow
Flow = require("lapis.flow").Flow
local limits = require("community.limits")
local assert_valid
assert_valid = require("lapis.validate").assert_valid
local shapes = require("community.helpers.shapes")
local types = require("lapis.validate.types")
local bool_t = types.boolean + types.empty / false + types.any / true
local TopicPolls
TopicPolls = require("community.models").TopicPolls
local TopicPollsFlow
do
  local _class_0
  local _parent_0 = Flow
  local _base_0 = {
    validate_params = function(self)
      return assert_valid(self.params, types.params_shape({
        {
          "choices",
          shapes.convert_array * types.array_of(types.params_shape(self.__class.CHOICE_VALIDATION))
        },
        unpack(self.__class.POLL_VALIDATION)
      }))
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
      shapes.default(true) * bool_t
    },
    {
      "hide_results",
      shapes.default(false) * bool_t
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
