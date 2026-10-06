db = require "lapis.db"

import Model, VirtualModel from require "community.model"

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

  class PollChoiceVoters extends VirtualModel
    @primary_key: {"poll_choice_id", "user_id"}

    @relations: {
      {"poll_choice", belongs_to: "PollChoices"}
      {"user", belongs_to: "Users"}
      {"vote", has_one: "PollVotes", key: {"poll_choice_id", "user_id"}}
    }

  @relations: {
    {"poll", belongs_to: "TopicPolls"}
    {"poll_votes", has_many: "PollVotes", key: "poll_choice_id"}
  }

  with_user: VirtualModel\make_loader "voters", (user_id) =>
    assert user_id, "expecting user id"
    PollChoiceVoters\load {
      user_id: user_id
      poll_choice_id: @id
    }

  -- Used by BrowsingFlow.preload_poll_voters. Sets recent_votes on each
  -- choice, newest first, with users loaded. Costs two queries regardless of
  -- how many votes the choices have
  @preload_recent_votes: (choices, limit=5) =>
    return choices unless next choices
    import PollVotes from require "community.models"
    import preload from require "lapis.db.model"

    votes = PollVotes\load_all db.query "
      select v.* from unnest(?::integer[]) as c(id)
      cross join lateral (
        select * from #{db.escape_identifier PollVotes\table_name!}
        where poll_choice_id = c.id and counted
        order by id desc
        limit ?
      ) v
      order by v.poll_choice_id, v.id desc
    ", db.array([c.id for c in *choices]), limit

    preload votes, "user"

    by_choice = {}
    for vote in *votes
      by_choice[vote.poll_choice_id] or= {}
      table.insert by_choice[vote.poll_choice_id], vote

    for choice in *choices
      choice.recent_votes = by_choice[choice.id] or {}

    choices

  name_for_display: =>
    @choice_text

  recount: =>
    import PollVotes from require "community.models"
    @update {
      vote_count: db.raw "(select count(*)
        from #{db.escape_identifier PollVotes\table_name!}
        where poll_choice_id = #{db.escape_identifier @@table_name!}.id and counted = true)"
    }

  delete: =>
    if super!
      -- delete all votes for this choice
      import PollVotes from require "community.models"
      db.delete PollVotes\table_name!, db.clause {
        {"poll_choice_id = ?", @id}
      }
      true

  -- Vote for this choice, aware of vote_type for the poll. When counted isn't
  -- provided it comes from CommunityUsers.count_poll_vote_for
  vote: (user, counted) =>
    assert user, "missing user"
    import TopicPolls, PollVotes, CommunityUsers from require "community.models"

    poll = @get_poll!
    return nil, "poll is closed" unless poll\is_open!

    if counted == nil
      counted = CommunityUsers\for_user(user)\count_poll_vote_for @

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

