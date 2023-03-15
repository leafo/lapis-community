db = require "lapis.db"
import Model from require "community.model"

import insert_on_conflict_ignore from require "community.helpers.models"

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

  @create: insert_on_conflict_ignore

  @find_subscription: (object, user) =>
    return nil unless user

    @find {
      user_id: user.id
      object_type: @object_type_for_object object
      object_id: object.id
    }

  @is_subscribed: (object, user, subscribed_by_default=false) =>
    return unless user

    sub = @find_subscription object, user
    if subscribed_by_default
      not sub or sub.subscribed
    else
      sub and sub.subscribed

  @subscribe: (object, user, subscribed_by_default=false) =>
    return unless user

    sub = @find_subscription object, user

    if subscribed_by_default
      if sub
        sub\delete!
        return true
      else
        return

    return if sub and sub.subscribed

    if sub
      sub\update subscribed: true
    else
      @create {
        user_id: user.id
        object_type: @object_type_for_object object
        object_id: object.id
      }

    true

  @unsubscribe: (object, user, subscribed_by_default=false) =>
    return unless user
    sub = @find_subscription object, user

    if subscribed_by_default
      if sub
        return unless sub.subscribed
        sub\update subscribed: false
      else
        @create {
          user_id: user.id
          object_type: @object_type_for_object object
          object_id: object.id
          subscribed: false
        }
      true
    else
      if sub
        sub\delete!
        return true


  is_subscribed: =>
    @subscribed
