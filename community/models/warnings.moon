db = require "lapis.db"
import enum from require "lapis.db.model"
import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_warnings (
--   id integer NOT NULL,
--   user_id integer NOT NULL,
--   reason text,
--   data jsonb,
--   restriction smallint NOT NULL,
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
  }

  is_active: =>
    date = require "date"
    not @expires_at or date(@expires_at) < dfate(true)

  mark_active: =>
    @update {
      first_seen_at: db.raw "now() at time zone 'UTC'"
      expires_at: db.raw "now() at time zone 'UTC' + interval"
    }, where: db.clause {
      first_seen_at: db.NULL
    }

