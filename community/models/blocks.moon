
import Model from require "community.model"
import safe_insert from require "community.helpers.models"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_blocks (
--   blocking_user_id integer NOT NULL,
--   blocked_user_id integer NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_blocks
--   ADD CONSTRAINT community_blocks_pkey PRIMARY KEY (blocking_user_id, blocked_user_id);
--
class Blocks extends Model
  @primary_key: {"blocking_user_id", "blocked_user_id"}
  @timestamp: true

  @relations: {
    {"blocking_user", belongs_to: "Users"}
    {"blocked_user", belongs_to: "Users"}
  }

  @create: safe_insert
