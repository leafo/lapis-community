db = require "lapis.db"
import Model from require "community.model"

import safe_insert from require "community.helpers.models"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_bookmarks (
--   user_id integer NOT NULL,
--   object_type integer DEFAULT 0 NOT NULL,
--   object_id integer NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_bookmarks
--   ADD CONSTRAINT community_bookmarks_pkey PRIMARY KEY (user_id, object_type, object_id);
-- CREATE INDEX community_bookmarks_user_id_created_at_idx ON community_bookmarks USING btree (user_id, created_at);
--
class Bookmarks extends Model
  @primary_key: { "user_id", "object_type", "object_id" }
  @timestamp: true

  @relations: {
    {"user", belongs_to: "Users"}
    {"object", polymorphic_belongs_to: {
      [1]: {"user", "Users"}
      [2]: {"topic", "Topics"}
      [3]: {"post", "Posts"}
    }}
  }

  @create: (opts={}) =>
    opts.object_type = @object_types\for_db opts.object_type
    safe_insert @, opts
