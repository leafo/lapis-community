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
--   start_date timestamp without time zone DEFAULT date_trunc('second'::text, (now() AT TIME ZONE 'utc'::text)) NOT NULL,
--   end_date timestamp without time zone NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_topic_polls
--   ADD CONSTRAINT community_topic_polls_pkey PRIMARY KEY (id);
-- CREATE INDEX community_topic_polls_topic_id_idx ON community_topic_polls USING btree (topic_id);
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

  delete: =>
    if super!
      -- clean up poll choices and votes
      for choice in *@get_poll_choices!
        choice\delete!
      true

  name_for_display: =>
    @poll_question

  allowed_to_edit: (user) =>
    @get_topic!\allowed_to_edit user

  allowed_to_vote: (user) =>
    @get_topic!\allowed_to_view user

  is_open: =>
    now = date(true)
    now >= date(@start_date) and now < date(@end_date)

  total_vote_count: =>
    sum = 0
    for choice in *@get_poll_choices!
      sum += choice.vote_count

    sum

