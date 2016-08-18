
db = require "lapis.db"
import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_topic_participants (
--   topic_id integer NOT NULL,
--   user_id integer NOT NULL,
--   posts_count integer DEFAULT 0 NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_topic_participants
--   ADD CONSTRAINT community_topic_participants_pkey PRIMARY KEY (topic_id, user_id);
--
class TopicParticipants extends Model
  @primary_key: {"topic_id", "user_id"}
  @timestamp: true

  @relations: {
    {"user", belongs_to: "Users"}
    {"topic", belongs_to: "Topics"}
  }

  @increment: (topic_id, user_id) =>
    import insert_on_conflict_update from require "community.helpers.models"

    col = "#{@table_name!}.posts_count"

    insert_on_conflict_update @, {
      :user_id, :topic_id
    }, {
      posts_count: 1
    }, {
      posts_count: db.raw "#{col} + 1"
    }

  @decrement: (topic_id, user_id) =>
    key = {:user_id, :topic_id}

    res = db.update @table_name!, {
      posts_count: db.raw "posts_count - 1"
    }, key, "posts_count"

    if res[1] and res[1].posts_count == 0
      key.posts_count = 0
      db.delete @table_name!, key
