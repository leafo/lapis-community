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
--   updated_at timestamp without time zone NOT NULL,
--   data jsonb
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

  -- actions to create post for
  @create_post_for: {
    "topic.move": true
    "topic.archive": true
    "topic.unarchive": true
    "topic.lock": true
    "topic.unlock": true
    "topic.hide": true
    "topic.unhide": true
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

    create_backing_post = opts.backing_post != false
    opts.backing_post = nil

    with l = super opts
      if log_objects
        l\set_log_objects log_objects

      if create_backing_post and @create_post_for[l.action]
        l\create_backing_post!

  set_log_objects: (objects) =>
    import ModerationLogObjects from require "community.models"

    for o in *objects
      ModerationLogObjects\create {
        moderation_log_id: @id
        object_type: ModerationLogObjects\object_type_for_object o
        object_id: o.id
      }

  create_backing_post: =>
    return nil, "not a topic moderation" unless @object_type == @@object_types.topic
    import Posts from require "community.models"

    post = Posts\create {
      moderation_log_id: @id
      body: ""
      topic_id: @object_id
      user_id: @user_id
    }

    topic = @get_object!
    topic\increment_from_post post
    post

  get_action_text: =>
    switch @action
      when "topic.move"
        "moved this topic to"
      when "topic.archive"
        "archived this topic"
      when "topic.unarchive"
        "unarchived this topic"
      when "topic.lock"
        "locked this topic"
      when "topic.unlock"
        "unlocked this topic"
      when "topic.hide"
        "unlisted this topic"
      when "topic.unhide"
        "relisted this topic"

  get_action_target: =>
    @get_target_category!

  get_target_category: =>
    unless @action == "topic.move" and @data and @data.target_category_id
      return nil, "no target category"

    if @target_category == nil
      import Categories from require "community.models"
      @target_category = Categories\find @data.target_category_id
      @target_category or= false

    @target_category

