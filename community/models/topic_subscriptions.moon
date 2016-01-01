
db = require "lapis.db"
import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_topic_subscriptions (
--   topic_id integer NOT NULL,
--   user_id integer NOT NULL,
--   subscribed boolean DEFAULT true NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_topic_subscriptions
--   ADD CONSTRAINT community_topic_subscriptions_pkey PRIMARY KEY (topic_id, user_id);
-- CREATE INDEX community_topic_subscriptions_user_id_idx ON community_topic_subscriptions USING btree (user_id);
--
class TopicSubscriptions extends Model
  @primary_key: {"topic_id", "user_id"}
  @timestamp: true

  @relations: {
    {"user", belongs_to: "Users"}
    {"topic", belongs_to: "Topics"}
  }
