db = require "lapis.db"
import Flow from require "lapis.flow"

limits = require "community.limits"

import assert_error from require "lapis.application"
import assert_valid, with_params from require "lapis.validate"
import require_current_user from require "community.helpers.app"

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

  validate_params_shape: =>
    choice_shape = types.params_shape @@CHOICE_VALIDATION

    types.params_shape {
      {"choices", shapes.convert_array * types.params_array choice_shape, {
        length: types.range(1, 20)
      }}

      unpack @@POLL_VALIDATION
    }

  validate_params: =>
    assert_valid @params, @validate_params_shape!

  vote: require_current_user with_params {
    {"choice_id", types.db_id}
    {"action", types.one_of {"create", "delete"}}
  }, (params) =>
    import PollChoices,PollVotes from require "community.models"

    choice = PollChoices\find params.choice_id
    poll = assert_error choice\get_poll!, "invalid poll"
    switch params.action
      when "create"
        assert_error poll\is_open!, "poll is closed" -- preempt for better error message
        assert_error poll\allowed_to_vote(@current_user), "not allowed to vote"
        assert_error choice\vote @current_user
      when "delete"
        assert_error poll\is_open!, "poll is closed"
        assert_error poll\allowed_to_vote(@current_user), "invalid poll"

        -- find existing vote
        vote = PollVotes\find {
          poll_choice_id: choice.id
          user_id: @current_user.id
        }

        if vote
          vote\delete!
          return true
        else
          nil, "invalid vote"


  -- creates new poll for topic from previously validated params. Will set
  -- choices on the poll from params.choices
  set_poll: (topic, params) =>
    import TopicPolls from require "community.models"

    poll_params = {
      poll_question: params.poll_question
      description: params.description
      anonymous: params.anonymous
      hide_results: params.hide_results
      vote_type: params.vote_type

      -- TODO: allow this to be specified, look into how we set date with timezone
      end_date: db.raw "date_trunc('second', now() AT TIME ZONE 'utc' + interval '1 day' )"
    }

    poll = if existing_poll = topic\get_poll!
      import filter_update from require "community.helpers.models"
      existing_poll\update filter_update existing_poll, poll_params
      existing_poll
    else
      poll_params.topic_id = topic.id
      TopicPolls\create poll_params

    if poll
      @set_choices poll, params.choices
      poll

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
