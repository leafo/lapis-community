import enum from require "lapis.db.model"
import Model from require "community.model"
import to_json from require "lapis.util"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_activity_logs (
--   id integer NOT NULL,
--   user_id integer NOT NULL,
--   object_type integer DEFAULT 0 NOT NULL,
--   object_id integer NOT NULL,
--   publishable boolean DEFAULT false NOT NULL,
--   action integer DEFAULT 0 NOT NULL,
--   data text,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_activity_logs
--   ADD CONSTRAINT community_activity_logs_pkey PRIMARY KEY (id);
-- CREATE INDEX community_activity_logs_object_type_object_id_idx ON community_activity_logs USING btree (object_type, object_id);
-- CREATE INDEX community_activity_logs_user_id_id_idx ON community_activity_logs USING btree (user_id, id);
--
class ActivityLogs extends Model
  @timestamp: true

  @actions: {
    topic: enum {
      create: 1
      delete: 2
    }

    post: enum {
      create: 1
      delete: 2
      edit: 3
      vote: 4
    }

    category: enum {
      create: 1
      edit: 2
    }
  }

  @relations: {
    {"user", belongs_to: "Users"}
    {"category", belongs_to: "Categories"}

    {"object", polymorphic_belongs_to: {
      [1]: {"topic", "Topics"}
      [2]: {"post", "Posts"}
      [3]: {"category", "Categories"}
    }}
  }

  @create: (opts={}) =>
    assert opts.user_id, "missing user_id"
    assert opts.action, "missing action"

    if opts.object
      object = assert opts.object, "missing object"
      opts.object = nil
      opts.object_id = assert object.id, "object does not have id"
      opts.object_type = @object_type_for_object object

    opts.object_type = @object_types\for_db opts.object_type

    type_name = @object_types\to_name opts.object_type
    actions = @actions[type_name]
    unless actions
      error "missing action for type: #{type_name}"
    opts.action = actions\for_db opts.action

    if opts.data
      opts.data = to_json opts.data

    super opts

  action_name: =>
    @@actions[@@object_types\to_name @object_type][@action]

