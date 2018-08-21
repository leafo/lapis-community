db = require "lapis.db"
import Model from require "community.model"

import insert_on_conflict_ignore from require "community.helpers.models"

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
    insert_on_conflict_ignore @, opts

  @get: (object, user) =>
    return nil unless user
    @find {
      user_id: user.id
      object_id: object.id
      object_type: @object_type_for_model object.__class
    }

  @save: (object, user) =>
    return unless user

    @create {
      user_id: user.id
      object_id: object.id
      object_type: @object_type_for_model object.__class
    }

  @remove: (object, user) =>
    if bookmark = @get object, user
      bookmark\delete!

