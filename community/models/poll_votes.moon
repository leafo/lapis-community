db = require "lapis.db"

import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_poll_votes (
--   id integer NOT NULL,
--   poll_choice_id integer NOT NULL,
--   user_id integer NOT NULL,
--   counted boolean DEFAULT true NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_poll_votes
--   ADD CONSTRAINT community_poll_votes_pkey PRIMARY KEY (id);
-- CREATE INDEX community_poll_votes_poll_choice_id_idx ON community_poll_votes USING btree (poll_choice_id);
-- CREATE INDEX community_poll_votes_user_id_idx ON community_poll_votes USING btree (user_id);
--
class PollVotes extends Model
  @timestamp: true

  @relations: {
    {"poll_choice", belongs_to: "PollChoices"}
    {"user", belongs_to: "Users"}
  }

  create: (opts={}) =>
    opts.created_at or= db.format_date!
    opts.updated_at or= db.format_date!

    res = unpack db.insert @@table_name!, opts, {
      on_conflict: "do_nothing"
      returning: "*"
    }

    if res.counted
      -- increment the vote count on the poll choice
      import PollChoices from require "community.models"
      db.update PollChoices\table_name!, {
        vote_count: db.raw "vote_count + 1"
      }, db.clause {
        {"id = ?", res.poll_choice_id}
      }

    @load res

  delete: =>
    deleted, res = super db.raw "*"

    if deleted
      removed_row = unpack res
      if removed_row.counted
        -- decrement the vote count on the poll choice
        import PollChoices from require "community.models"
        db.update PollChoices\table_name!, {
          vote_count: db.raw "vote_count - 1"
        }, db.clause {
          {"id = ?", removed_row.poll_choice_id}
        }

      true

  -- update the counted field and correctly increment the vote count
  set_counted: (counted) =>
    updated = @update {
      counted: counted
    }, where: db.clause {
      {"counted = ?", not counted}
    }

    -- update the counter on the pool choice
    if updated
      delta = if counted then 1 else -1

      import PollChoices from require "community.models"
      db.update PollChoices\table_name!, {
        vote_count: db.raw db.interpolate_query "vote_count + ?", delta
      }, db.clause {
        {"id = ?", @poll_choice_id}
      }
      true

