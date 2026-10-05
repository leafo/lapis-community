db = require "lapis.db"

date = require "date"

import enum from require "lapis.db.model"

import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_topic_polls (
--   id integer NOT NULL,
--   topic_id integer NOT NULL,
--   poll_question text NOT NULL,
--   description text,
--   vote_type smallint NOT NULL,
--   anonymous boolean DEFAULT true NOT NULL,
--   hide_results boolean DEFAULT false NOT NULL,
--   version integer DEFAULT 1 NOT NULL,
--   start_date timestamp without time zone DEFAULT date_trunc('second'::text, (now() AT TIME ZONE 'utc'::text)) NOT NULL,
--   end_date timestamp without time zone NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_topic_polls
--   ADD CONSTRAINT community_topic_polls_pkey PRIMARY KEY (id);
-- CREATE UNIQUE INDEX community_topic_polls_topic_id_idx ON community_topic_polls USING btree (topic_id);
--
class TopicPolls extends Model
  @timestamp: true

  @relations: {
    {"topic", belongs_to: "Topics"}
    {"poll_choices", has_many: "PollChoices", key: "poll_id", order: "position ASC"}
  }

  @vote_types: enum {
    single: 1 -- user can vote on a single choice
    multiple: 2 -- user can vote on any number of choices
  }

  @create: (opts={}) =>
    opts.vote_type = @vote_types\for_db opts.vote_type or "single"
    super opts

  -- Used by TopicPollsFlow.set_poll and PendingPosts.promote. Doesn't
  -- validate anything, dates should already be checked by set_poll_dates
  @create_for_topic: (topic, params) =>
    import PollChoices from require "community.models"
    limits = require "community.limits"

    poll = @create {
      topic_id: topic.id
      poll_question: params.poll_question
      description: params.description
      anonymous: params.anonymous
      hide_results: params.hide_results
      vote_type: params.vote_type
      start_date: params.start_date
      end_date: params.end_date or db.raw db.interpolate_query(
        "date_trunc('second', now() AT TIME ZONE 'utc') + ? * interval '1 second'",
        limits.DEFAULT_POLL_DURATION
      )
    }

    for idx, choice in ipairs params.choices
      PollChoices\create {
        poll_id: poll.id
        choice_text: choice.choice_text
        description: choice.description
        position: choice.position or idx
      }

    poll

  -- Used by new_topic to store a poll on a pending post. db.NULL doesn't
  -- survive JSON encoding
  @pending_data: (params) =>
    not_null = (v) -> v unless v == db.NULL

    {
      poll_question: params.poll_question
      description: not_null params.description
      anonymous: params.anonymous
      hide_results: params.hide_results
      vote_type: params.vote_type
      start_date: params.start_date
      end_date: params.end_date
      choices: for c in *params.choices
        {
          choice_text: c.choice_text
          description: not_null c.description
          position: c.position
        }
    }

  delete: =>
    if super!
      -- clean up poll choices and votes
      for choice in *@get_poll_choices!
        choice\delete!
      true

  name_for_display: =>
    @poll_question

  reset_votes: =>
    import PollChoices, PollVotes from require "community.models"

    res = db.delete PollVotes\table_name!, db.clause {
      {"poll_choice_id in (select id from #{db.escape_identifier PollChoices\table_name!} where poll_id = ?)", @id}
    }

    db.update PollChoices\table_name!, { vote_count: 0 }, { poll_id: @id }
    res.affected_rows

  allowed_to_edit: (user) =>
    @get_topic!\allowed_to_edit user

  allowed_to_vote: (user) =>
    unless @is_open!
      return nil, "poll is closed"

    @get_topic!\allowed_to_view user

  is_open: =>
    now = date(true)
    now >= date(@start_date) and now < date(@end_date)

  is_upcoming: =>
    date(true) < date(@start_date)

  is_closed: =>
    date(true) >= date(@end_date)

  allowed_to_view_results: (user) =>
    return true unless @hide_results
    return false unless user

    topic = @get_topic!
    return true if user.id == topic.user_id
    topic\allowed_to_moderate user

  allowed_to_view_voters: (user) =>
    return false unless @allowed_to_view_results user
    return true unless @anonymous
    return false unless user
    @get_topic!\allowed_to_moderate user

  -- includes uncounted votes, unlike total_vote_count
  has_votes: =>
    import PollChoices, PollVotes from require "community.models"
    res = PollVotes\select "where poll_choice_id in (select id from #{db.escape_identifier PollChoices\table_name!} where poll_id = ?) limit 1", @id, fields: "1"
    next(res) != nil

  total_vote_count: =>
    sum = 0
    for choice in *@get_poll_choices!
      sum += choice.vote_count

    sum

