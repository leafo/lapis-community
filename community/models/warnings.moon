db = require "lapis.db"
import enum from require "lapis.db.model"
import Model from require "community.model"

import db_json from require "community.helpers.models"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_warnings (
--   id integer NOT NULL,
--   user_id integer NOT NULL,
--   reason text,
--   data jsonb,
--   restriction smallint DEFAULT 1 NOT NULL,
--   duration interval NOT NULL,
--   first_seen_at timestamp without time zone,
--   expires_at timestamp without time zone,
--   moderating_user_id integer,
--   post_id integer,
--   post_report_id integer,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_warnings
--   ADD CONSTRAINT community_warnings_pkey PRIMARY KEY (id);
-- CREATE INDEX community_warnings_user_id_idx ON community_warnings USING btree (user_id);
--
class Warnings extends Model
  @timestamp: true
  @relations: {
    {"user", belongs_to: "Users"}
    {"moderating_user", belongs_to: "Users"}
    {"post", belongs_to: "Posts"}
    {"post_report", belongs_to: "PostReports"}
  }

  @create: (opts, ...) =>
    if opts.restriction
      opts.restriction = @restrictions\for_db opts.restriction

    if opts.data
      opts.data = db_json opts.data

    super opts, ...

  @restrictions: enum {
    notify: 1 -- user is displayd warning but they can function normally
    block_posting: 2
    pending_posting: 3
  }

  is_active: =>
    date = require "date"
    not @expires_at or date(true) < date(@expires_at)

  -- this should be called the first time the user views the warning to start
  -- the restriction for the warning duration
  start_warning: =>
    @update {
      first_seen_at: db.raw "date_trunc('second', now() at time zone 'UTC')"
      expires_at: db.raw [[date_trunc('second', now() at time zone 'UTC') + duration]]
    }, where: db.clause {
      first_seen_at: db.NULL
    }

  -- immediately end the warning if it's not already over
  end_warning: =>
    @update {
      first_seen_at: db.raw "coalesce(first_seen_at, date_trunc('second', now() at time zone 'UTC'))"
      expires_at: db.raw [[date_trunc('second', now() at time zone 'UTC')]]
    }, where: db.clause {
      "expires_at IS NULL or now() at time zone 'utc' < expires_at"
    }
