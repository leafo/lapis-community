import enum from require "lapis.db.model"
import Model from require "community.model"

import safe_insert from require "community.helpers.models"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_moderation_log_objects (
--   moderation_log_id integer NOT NULL,
--   object_type integer DEFAULT 0 NOT NULL,
--   object_id integer NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_moderation_log_objects
--   ADD CONSTRAINT community_moderation_log_objects_pkey PRIMARY KEY (moderation_log_id, object_type, object_id);
--
class ModerationLogObjects extends Model
  @timestamp: true

  @relations: {
    {"moderation_log", belongs_to: "ModerationLogs"}

    {"object", polymorphic_belongs_to: {
      [1]: {"user", "Users"}
      [2]: {"topic", "Topics"}
    }}
  }

  @create: safe_insert
