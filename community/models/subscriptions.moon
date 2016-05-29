db = require "lapis.db"
import Model from require "community.model"

import safe_insert from require "community.helpers.models"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_subscriptions (
--   object_type smallint NOT NULL,
--   object_id integer NOT NULL,
--   user_id integer NOT NULL,
--   subscribed boolean DEFAULT true NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_subscriptions
--   ADD CONSTRAINT community_subscriptions_pkey PRIMARY KEY (object_type, object_id, user_id);
-- CREATE INDEX community_subscriptions_user_id_idx ON community_subscriptions USING btree (user_id);
--
class Subscriptions extends Model
  @primary_key: {"object_type", "object_id", "user_id"}

  @timestamp: true

  @relations: {
    {"user", belongs_to: "Users"}
    {"object", polymorphic_belongs_to: {
      [1]: {"topic", "Topics"}
      [2]: {"category", "Categories"}
    }}
  }

  @create: safe_insert

  @subscribe: (object, user, subscribed_by_default=false) =>
  @unsubscribe: (object, user, subscribed_by_default=false) =>
