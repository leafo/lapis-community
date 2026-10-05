db = require "lapis.db"
import Flow from require "lapis.flow"

limits = require "community.limits"

import assert_error from require "lapis.application"
import assert_valid, with_params from require "lapis.validate"
import require_current_user from require "community.helpers.app"

shapes = require "community.helpers.shapes"
types = require "lapis.validate.types"

import TopicPolls from require "community.models"

class TopicPollsFlow extends Flow
  @POLL_VALIDATION: {
    {"poll_question",            types.limited_text(limits.MAX_TITLE_LEN)}
    {"description",              types.empty / db.NULL + types.limited_text(limits.MAX_TITLE_LEN)}
    {"anonymous",                types.empty / false + types.any / true}
    {"hide_results",             types.empty / false + types.any / true}
    {"start_date",               types.empty / nil + shapes.utc_datetime}
    {"end_date",                 types.empty / nil + shapes.utc_datetime}
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

    -- set_choices only applies the first entry for an id, so duplicates could
    -- be used to slip changes past locked_poll_changes
    unique_ids = types.custom (choices) ->
      seen = {}
      for c in *choices
        continue unless c.id
        return nil, "duplicate choice id" if seen[c.id]
        seen[c.id] = true

      true

    types.params_shape {
      {"choices", shapes.convert_array * types.params_array(choice_shape, {
        length: types.range(1, 20)
      }) * unique_ids}

      unpack @@POLL_VALIDATION
    }

  validate_params: =>
    assert_valid @params, @validate_params_shape!

  vote: require_current_user with_params {
    {"choice_id", types.db_id}
    {"action", types.one_of {"create", "delete"}}
    {"poll_version", types.empty + types.db_id}
  }, (params) =>
    import PollChoices,PollVotes from require "community.models"

    choice = assert_error PollChoices\find(params.choice_id), "invalid poll"
    poll = assert_error choice\get_poll!, "invalid poll"
    switch params.action
      when "create"
        assert_error poll\is_open!, "poll is closed" -- preempt for better error message
        assert_error poll\allowed_to_vote(@current_user), "not allowed to vote"

        assert_error params.poll_version, "missing poll version"
        assert_error params.poll_version == poll.version,
          "this poll has changed since you loaded it, please review it and vote again"

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


  -- Used by set_poll to decide when to bump the poll version, and by
  -- locked_poll_changes. params must be the output of validate_params_shape
  content_changes: (poll, params) =>
    changes = {}

    if params.poll_question != poll.poll_question
      table.insert changes, "question"

    if TopicPolls.vote_types\for_db(params.vote_type) != poll.vote_type
      table.insert changes, "vote type"

    choices_by_id = { c.id, c for c in *params.choices when c.id }

    for choice in *poll\get_poll_choices!
      choice_params = choices_by_id[choice.id]
      unless choice_params
        table.insert changes, "removed choice"
        continue

      if choice_params.choice_text != choice.choice_text
        table.insert changes, "choice text"

      new_description = choice_params.description
      new_description = nil if new_description == db.NULL
      if new_description != choice.description
        table.insert changes, "choice description"

    for c in *params.choices
      unless c.id
        table.insert changes, "added choice"
        break

    changes

  -- Used by edit_post to stop non-moderators from changing what existing
  -- votes mean. params must be the output of validate_params_shape
  locked_poll_changes: (poll, params) =>
    return nil unless poll\has_votes!

    changes = [c for c in *@content_changes poll, params when c != "added choice"]

    if poll.anonymous and not params.anonymous
      table.insert changes, "anonymous"

    if next changes
      changes

  -- Called before creating a poll, after validate_params_shape. Not used for
  -- edits, an existing poll's dates are never changed by set_poll
  set_poll_dates: (params) =>
    date = require "date"
    format = "%Y-%m-%d %H:%M:%S"

    now = date true
    start = params.start_date and date params.start_date
    -- also covers a client clock running slightly behind
    start = now if not start or start < now

    if date.diff(start, now)\spanseconds! > limits.MAX_POLL_START_DELAY
      return nil, "poll can't start more than #{math.floor limits.MAX_POLL_START_DELAY / 86400} days from now"

    finish = if params.end_date
      date params.end_date
    else
      start\copy!\addseconds limits.DEFAULT_POLL_DURATION

    duration = date.diff(finish, start)\spanseconds!

    if duration < limits.MIN_POLL_DURATION
      return nil, "poll must be open for at least #{math.floor limits.MIN_POLL_DURATION / 3600} hour(s)"

    if duration > limits.MAX_POLL_DURATION
      return nil, "poll can't be open for more than #{math.floor limits.MAX_POLL_DURATION / 86400} days"

    params.start_date = start\fmt format
    params.end_date = finish\fmt format
    true

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
    }

    if existing_poll = topic\get_poll!
      import filter_update from require "community.helpers.models"
      poll_update = filter_update existing_poll, poll_params

      -- invalidates vote forms rendered before this edit
      if next @content_changes existing_poll, params
        poll_update.version = db.raw "version + 1"

      -- dates are left alone so editing a poll can't reopen or extend it
      existing_poll\update poll_update
      @set_choices existing_poll, params.choices
      existing_poll
    else
      TopicPolls\create_for_topic topic, params

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
