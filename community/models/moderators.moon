import Model from require "community.model"

import insert_on_conflict_ignore from require "community.helpers.models"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_moderators (
--   user_id integer NOT NULL,
--   object_type integer NOT NULL,
--   object_id integer NOT NULL,
--   admin boolean DEFAULT false NOT NULL,
--   accepted boolean DEFAULT false NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_moderators
--   ADD CONSTRAINT community_moderators_pkey PRIMARY KEY (user_id, object_type, object_id);
-- CREATE INDEX community_moderators_object_type_object_id_created_at_idx ON community_moderators USING btree (object_type, object_id, created_at);
--
class Moderators extends Model
  @timestamp: true
  @primary_key: {"user_id", "object_type", "object_id"}

  -- all moderatable objects must implement the following methods:
  -- \allowed_to_edit_moderators(user)
  -- \allowed_to_moderate(user, ignore_admin)

  @relations: {
    {"object", polymorphic_belongs_to: {
      [1]: {"category", "Categories"}
      [2]: {"category_group", "CategoryGroups"}
    }}

    {"user", belongs_to: "Users"}
  }

  @create: (opts={}) =>
    assert opts.user_id, "missing user_id"

    if opts.object
      opts.object_id = opts.object.id
      opts.object_type = @object_type_for_object opts.object
      opts.object = nil
    else
      assert opts.id, "missing object_id"
      opts.object_type = @object_types\for_db opts.object_type

    insert_on_conflict_ignore @, opts

  @find_for_object_user: (object, user) =>
    return nil, "invalid object" unless object
    return nil, "invalid user" unless user

    @find {
      object_type: @object_type_for_object object
      object_id: object.id
      user_id: user.id
    }
