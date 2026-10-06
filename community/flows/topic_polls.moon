db = require "lapis.db"
import Flow from require "lapis.flow"

limits = require "community.limits"

import assert_error from require "lapis.application"
import assert_valid, with_params from require "lapis.validate"
import require_current_user from require "community.helpers.app"

shapes = require "community.helpers.shapes"
types = require "lapis.validate.types"

import TopicPolls from require "community.models"

date_format = "%Y-%m-%d %H:%M:%S"

check_duration = (start, finish) ->
  date = require "date"
  duration = date.diff(finish, start)\spanseconds!

  if duration < limits.MIN_POLL_DURATION
    return nil, "poll must be open for at least #{math.floor limits.MIN_POLL_DURATION / 3600} hour(s)"

  if duration > limits.MAX_POLL_DURATION
    return nil, "poll can't be open for more than #{math.floor limits.MAX_POLL_DURATION / 86400} days"

  true

class TopicPollsFlow extends Flow
  expose_assigns: true

  @POLL_VALIDATION: {
    {"poll_question",            types.limited_text(limits.MAX_TITLE_LEN)}
    {"description",              types.empty / db.NULL + types.limited_text(limits.MAX_TITLE_LEN)}
    {"anonymous",                types.empty / false + types.any / true}
    {"hide_results",             types.empty / false + types.any / true}
    {"end_date",                 types.empty / nil + shapes.utc_timestamp}
    {"vote_type",                shapes.default("single") * types.db_enum(TopicPolls.vote_types)}
  }

  @CHOICE_VALIDATION: {
    {"id",                       types.db_id + types.empty}
    {"choice_text",              types.limited_text(limits.MAX_TITLE_LEN)}
    {"description",              types.empty / db.NULL + types.limited_text(limits.MAX_TITLE_LEN)}
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

  -- Used by new_topic and edit_post, params is the table holding the poll
  -- field so errors are prefixed with "poll:". Runs the text through
  -- TopicPolls.filter_text
  validate_poll: (params) =>
    {:poll} = assert_valid params, types.params_shape {
      {"poll", @validate_params_shape!}
    }

    filter = (text) ->
      return text if text == db.NULL
      assert_error TopicPolls\filter_text text

    poll.poll_question = filter poll.poll_question
    poll.description = filter poll.description

    for choice in *poll.choices
      choice.choice_text = filter choice.choice_text
      choice.description = filter choice.description

    poll

  vote: require_current_user with_params {
    {"choice_id", types.db_id}
    {"action", types.one_of {"create", "delete"}}
    {"poll_version", types.empty + types.db_id}
  }, (params) =>
    import PollChoices,PollVotes from require "community.models"

    @choice = assert_error PollChoices\find(params.choice_id), "invalid poll"
    @poll = assert_error @choice\get_poll!, "invalid poll"

    assert_error @poll\is_open!, "poll is closed" -- preempt for better error message
    assert_error @poll\allowed_to_vote(@current_user, @_req), "not allowed to vote"

    switch params.action
      when "create"
        assert_error params.poll_version, "missing poll version"
        assert_error params.poll_version == @poll.version,
          "this poll has changed since you loaded it, please review it and vote again"

        @vote = assert_error @choice\vote @current_user
      when "delete"
        vote = assert_error PollVotes\find({
          poll_choice_id: @choice.id
          user_id: @current_user.id
        }), "invalid vote"

        vote\delete!

    true


  -- Request handler for listing who voted for a choice, sets @votes and
  -- @next_page. next_page can lead to an empty page when the last page was
  -- exactly full
  choice_voters: (opts={}) =>
    import PollChoices, PollVotes from require "community.models"
    import OrderedPaginator from require "lapis.db.pagination"
    import preload from require "lapis.db.model"

    params = assert_valid @params, types.params_shape {
      {"choice_id", types.db_id}
      {"before", types.empty + types.db_id}
    }

    @choice = assert_error PollChoices\find(params.choice_id), "invalid poll"
    @poll = assert_error @choice\get_poll!, "invalid poll"
    assert_error @poll\get_topic!\allowed_to_view(@current_user, @_req), "invalid poll"
    assert_error @poll\allowed_to_view_voters(@current_user), "not allowed to view voters"

    per_page = opts.per_page or limits.POLL_VOTERS_PER_PAGE

    pager = OrderedPaginator PollVotes, "id", "where ?", db.clause({
      poll_choice_id: @choice.id
      counted: true
    }), {
      :per_page
      prepare_results: (votes) ->
        preload votes, "user"
        votes
    }

    @votes = pager\before params.before

    @next_page = if #@votes == per_page
      { before: @votes[#@votes].id }

    @votes, @next_page

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

  -- Used by edit_post, every submitted choice id must belong to the poll.
  -- params must be the output of validate_params_shape
  validate_choice_ids: (poll, params) =>
    existing_ids = { c.id, true for c in *poll\get_poll_choices! }

    for c in *params.choices
      if c.id and not existing_ids[c.id]
        return nil, "invalid poll choice"

    true

  -- Used by edit_post to stop non-moderators from changing what existing
  -- votes mean. params must be the output of validate_params_shape
  locked_poll_changes: (poll, params) =>
    return nil unless poll\has_votes!

    changes = [c for c in *@content_changes poll, params when c != "added choice"]

    if poll.anonymous and not params.anonymous
      table.insert changes, "anonymous"

    if next changes
      changes

  -- Called after validate_params_shape, before set_poll. For a new poll the
  -- end_date defaults and the duration is measured from now. For an existing
  -- poll end_date is optional and the duration is measured from the poll's
  -- start. A past end_date closes the poll now, and a closed poll's end_date
  -- is left alone so an edit can't reopen it
  validate_end_date: (params, poll) =>
    date = require "date"
    now = date true

    local start, finish

    if poll
      if not params.end_date or poll\is_closed!
        params.end_date = nil
        return true

      start = date poll.start_date
      finish = date params.end_date

      if finish <= now
        params.end_date = now\fmt date_format
        return true
    else
      start = now
      finish = if params.end_date
        date params.end_date
      else
        now\copy!\addseconds limits.DEFAULT_POLL_DURATION

    ok, err = check_duration start, finish
    return nil, err unless ok

    params.end_date = finish\fmt date_format
    true

  load_poll_for_moderation: =>
    TopicsFlow = require "community.flows.topics"
    topics_flow = TopicsFlow @
    topics_flow\load_topic_for_moderation!
    poll = assert_error topics_flow.topic\get_poll!, "topic has no poll"
    topics_flow, poll

  -- For the topic's author or a moderator. Only a moderator closing someone
  -- else's poll is logged
  close_poll: require_current_user =>
    TopicsFlow = require "community.flows.topics"
    topics_flow = TopicsFlow @
    topics_flow\load_topic!
    topic = topics_flow.topic

    poll = assert_error topic\get_poll!, "topic has no poll"
    assert_error poll\allowed_to_edit(@current_user), "invalid user"
    assert_error not poll\is_closed!, "poll is already closed"

    params = assert_valid @params, types.params_shape {
      {"reason", types.empty + types.limited_text limits.MAX_BODY_LEN}
    }

    date = require "date"
    poll\update end_date: date(true)\fmt date_format

    if @current_user.id != topic.user_id
      topics_flow\write_moderation_log "topic.close_poll", params.reason

    true

  delete_poll: require_current_user =>
    topics_flow, poll = @load_poll_for_moderation!

    params = assert_valid @params, types.params_shape {
      {"reason", types.empty + types.limited_text limits.MAX_BODY_LEN}
    }

    poll\delete!
    topics_flow\write_moderation_log "topic.delete_poll", params.reason
    true

  reset_poll_votes: require_current_user =>
    topics_flow, poll = @load_poll_for_moderation!

    params = assert_valid @params, types.params_shape {
      {"reason", types.empty + types.limited_text limits.MAX_BODY_LEN}
    }

    deleted_count = poll\reset_votes!
    topics_flow\write_moderation_log "topic.reset_poll_votes", params.reason, {
      data: { deleted_votes: deleted_count }
    }

    true

  -- creates new poll for topic from previously validated params. Will set
  -- choices on the poll from params.choices
  set_poll: (topic, params) =>
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

      -- validate_end_date decides if end_date can change
      poll_update.end_date = params.end_date if params.end_date

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

    -- Process incoming choices, order of the array is the position
    for position, choice_params in ipairs choices
      if choice_params.id
        -- Update existing choice
        existing_choice = assert existing_choices_map[choice_params.id], "invalid poll choice"
        existing_choice\update {
          choice_text: choice_params.choice_text,
          description: choice_params.description,
          :position
        }
        -- clear it from remiaing choices
        existing_choices_map[choice_params.id] = nil
      else
        -- Create new choice
        PollChoices\create {
          poll_id: poll.id
          choice_text: choice_params.choice_text
          description: choice_params.description
          :position
        }

    -- Delete remaining choices that were not updated
    for _, choice in pairs existing_choices_map
      choice\delete!

    true
