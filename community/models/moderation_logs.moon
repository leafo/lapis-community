import enum from require "lapis.db.model"
import Model from require "community.model"
import to_json from require "lapis.util"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_moderation_logs (
--   id integer NOT NULL,
--   category_id integer,
--   object_type integer DEFAULT 0 NOT NULL,
--   object_id integer NOT NULL,
--   user_id integer NOT NULL,
--   action character varying(255) NOT NULL,
--   reason text,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_moderation_logs
--   ADD CONSTRAINT community_moderation_logs_pkey PRIMARY KEY (id);
-- CREATE INDEX community_moderation_logs_category_id_id_idx ON community_moderation_logs USING btree (category_id, id) WHERE (category_id IS NOT NULL);
-- CREATE INDEX community_moderation_logs_object_type_object_id_action_id_idx ON community_moderation_logs USING btree (object_type, object_id, action, id);
-- CREATE INDEX community_moderation_logs_user_id_idx ON community_moderation_logs USING btree (user_id);
--
class ModerationLogs extends Model
  @timestamp: true

  @relations: {
    {"user", belongs_to: "Users"}
    {"category", belongs_to: "Categories"}
    {"log_objects", has_many: "ModerationLogObjects"}

    {"object", polymorphic_belongs_to: {
      [1]: {"topic", "Topics"}
      [2]: {"category", "Categories"}
      [3]: {"post_report", "PostReports"}
      [4]: {"category_group", "CategoryGroups"}
    }}
  }

  @create: (opts={}) =>
    assert opts.user_id, "missing user_id"
    assert opts.action, "missing action"

    if type(opts.data) == "table"
      opts.data = to_json opts.data

    object = assert opts.object, "missing object"
    opts.object = nil
    opts.object_id = object.id
    opts.object_type = @object_type_for_object object

    log_objects = opts.log_objects
    opts.log_objects = nil

    with l = Model.create @, opts
      if log_objects
        l\set_log_objects log_objects

  set_log_objects: (objects) =>
    import ModerationLogObjects from require "community.models"

    for o in *objects
      ModerationLogObjects\create {
        moderation_log_id: @id
        object_type: ModerationLogObjects\object_type_for_object o
        object_id: o.id
      }

