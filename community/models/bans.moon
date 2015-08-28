
import enum from require "lapis.db.model"
import Model from require "community.model"

import safe_insert from require "community.helpers.models"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_bans (
--   object_type integer DEFAULT 0 NOT NULL,
--   object_id integer NOT NULL,
--   banned_user_id integer NOT NULL,
--   reason text,
--   banning_user_id integer,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_bans
--   ADD CONSTRAINT community_bans_pkey PRIMARY KEY (object_type, object_id, banned_user_id);
-- CREATE INDEX community_bans_banned_user_id_idx ON community_bans USING btree (banned_user_id);
-- CREATE INDEX community_bans_banning_user_id_idx ON community_bans USING btree (banning_user_id);
--
class Bans extends Model
  @timestamp: true
  @primary_key: {"object_type", "object_id", "banned_user_id"}

  @relations: {
    {"banned_user", belongs_to: "Users"}
    {"banning_user", belongs_to: "Users"}

    {"object", polymorphic_belongs_to: {
      [1]: {"category", "Categories"}
      [2]: {"topic", "Topics"}
    }}
  }

  @find_for_object: (object, user) =>
    return nil unless user
    Bans\find {
      object_type: @object_type_for_object object
      object_id: object.id
      banned_user_id: user.id
    }

  @create: (opts) =>
    assert opts.object, "missing object"

    opts.object_id = opts.object.id
    opts.object_type = @object_type_for_object opts.object
    opts.object = nil

    safe_insert @, opts

