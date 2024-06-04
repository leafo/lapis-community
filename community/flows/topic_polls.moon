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
    {"position",                 types.empty + types.db_id}
  }

  validate_params: =>
    assert_valid @params, types.params_shape {
      {"choices", shapes.convert_array * types.array_of types.params_shape @@CHOICE_VALIDATION}

      unpack @@POLL_VALIDATION
    }

  -- this merges the parsed choice params with the existing choices in the database
  -- choices with ids should be updated, and new choices should be created
  -- and choices with ids that are not in the params should be deleted
  set_choices: (poll, choices) =>
    assert poll, "missing poll id"
    import PollChoices from require "community.models"

    existing_choices = poll\get_poll_choices!
    existing_choices_map = { choice.id, choice for choice in *existing_choices }

    -- Process incoming choices
    for idx, choice_params in ipairs choices
      choice_params.position or= idx

      if choice_params.id
        -- Update existing choice
        existing_choice = existing_choices_map[choice_params.id]
        if existing_choice
          existing_choice\update {
            choice_text: choice_params.choice_text,
            description: choice_params.description,
            position: choice_params.position
          }
          -- clear it from remiaing choices
          existing_choices_map[choice_params.id] = nil
        else
          -- choice not found, just ignore
          continue
      else
        -- Create new choice
        PollChoices\create {
          poll_id: poll.id
          choice_text: choice_params.choice_text
          description: choice_params.description
          position: choice_params.position
        }

    -- Delete remaining choices that were not updated
    for _, choice in pairs existing_choices_map
      choice\delete!

    true
