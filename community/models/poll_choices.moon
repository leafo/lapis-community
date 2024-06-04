db = require "lapis.db"

import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_poll_choices (
--   id integer NOT NULL,
--   poll_id integer NOT NULL,
--   choice_text text NOT NULL,
--   vote_count integer DEFAULT 0 NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL,
--   "position" integer DEFAULT 0 NOT NULL
-- );
-- ALTER TABLE ONLY community_poll_choices
--   ADD CONSTRAINT community_poll_choices_pkey PRIMARY KEY (id);
-- CREATE INDEX community_poll_choices_poll_id_idx ON community_poll_choices USING btree (poll_id);
--
class PollChoices extends Model
  @timestamp: true

  @relations: {
    {"poll", belongs_to: "TopicPolls"}
    {"poll_votes", has_many: "PollVotes", key: "poll_choice_id"}
  }

  recount: =>
    import PollVotes from require "community.models"
    @update {
      vote_count: db.raw "(select count(*)
        from #{db.escape_identifier PollVotes\table_name!}
        where poll_choice_id = #{db.escape_identifier @@table_name!}.id and counted = true)"
    }

