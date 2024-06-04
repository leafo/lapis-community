db = require "lapis.db"

import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_poll_choices (
--   id integer NOT NULL,
--   poll_id integer NOT NULL,
--   choice_text text NOT NULL,
--   description text,
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

  name_for_display: =>
    @choice_text

  recount: =>
    import PollVotes from require "community.models"
    @update {
      vote_count: db.raw "(select count(*)
        from #{db.escape_identifier PollVotes\table_name!}
        where poll_choice_id = #{db.escape_identifier @@table_name!}.id and counted = true)"
    }

  --- Set the vote for the user, aware of vote_type for the poll
  --- @param user User The user who is voting
  --- @return PollVotes The vote if it was created
  vote: (user, counted=true) =>
    assert user, "missing user"
    import TopicPolls, PollVotes from require "community.models"

    poll = @get_poll!
    return nil, "poll is closed" unless poll\is_open!

    -- Create the vote
    vote = PollVotes\create {
      poll_choice_id: @id
      user_id: user.id
      :counted
    }

    unless vote
      return nil, "could not create vote"

    -- if vote_type is single, clear out other votes
    if poll.vote_type == TopicPolls.vote_types.single
      other_votes = PollVotes\select db.clause {
        {"user_id = ?", user.id}
        {"poll_choice_id in (select id from #{db.escape_identifier PollChoices\table_name!} where poll_id = ?)", poll.id}
        {"id != ?", vote.id}
      }
      for other_vote in *other_votes
        other_vote\delete!

    vote

