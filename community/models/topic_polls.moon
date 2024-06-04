db = require "lapis.db"

date = require "date"

import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_topic_polls (
--   id integer NOT NULL,
--   topic_id integer NOT NULL,
--   poll_question text NOT NULL,
--   description text,
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

  is_open: =>
    now = date(true)
    now >= date(@start_date) and now < date(@end_date)

