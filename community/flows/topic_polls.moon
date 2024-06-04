db = require "lapis.db"
import Flow from require "lapis.flow"

limits = require "community.limits"

import assert_valid from require "lapis.validate"

shapes = require "community.helpers.shapes"
types = require "lapis.validate.types"

bool_t = types.boolean + types.empty / false + types.any / true

import TopicPolls from require "community.models"

class TopicPollsFlow extends Flow
  @POLL_VALIDATION: {
    {"poll_question",            types.limited_text(limits.MAX_TITLE_LEN)}
    {"description",              types.empty / db.NULL + types.limited_text(limits.MAX_TITLE_LEN)}
    {"anonymous",                shapes.default(true) * bool_t}
    {"hide_results",             shapes.default(false) * bool_t}
    -- {"end_date", types.db_datetime}, -- TODO: figure out how we want to parse this
    -- TODO consdier just passing duration in hours
    {"vote_type",                shapes.default("single") * types.db_enum(TopicPolls.vote_types)}
  }

  @CHOICE_VALIDATION: {
    {"id",                       types.db_id + types.empty}
    {"choice_text",              types.limited_text(limits.MAX_TITLE_LEN)}
    {"description",              types.empty / db.NULL + types.limited_text(limits.MAX_TITLE_LEN)}
    {"position",                 types.db_id}
  }

  validate_params: =>
    assert_valid @params, types.params_shape {
      {"choices", shapes.convert_array * types.array_of types.params_shape @@CHOICE_VALIDATION}

      unpack @@POLL_VALIDATION
    }

  -- this merges the parsed choice params with the existing choices in the database
  -- choicess with ids should be updated, and new choices should be created
  -- and choices with ids that are not in the params should be deleted
  set_choices: (poll, choices) =>
