db = require "lapis.db"
import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_user_topic_last_seens (
--   user_id integer NOT NULL,
--   topic_id integer NOT NULL,
--   post_id integer NOT NULL
-- );
-- ALTER TABLE ONLY community_user_topic_last_seens
--   ADD CONSTRAINT community_user_topic_last_seens_pkey PRIMARY KEY (user_id, topic_id);
-- CREATE INDEX community_user_topic_last_seens_topic_id_idx ON community_user_topic_last_seens USING btree (topic_id);
--
class UserTopicLastSeens extends Model
  @primary_key: {"user_id", "topic_id"}

  @relations: {
    {"user", belongs_to: "Users"}
    {"topic", belongs_to: "Topics"}
    {"post", belongs_to: "Posts"}
  }

