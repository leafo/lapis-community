db = require "lapis.db"
import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_user_category_last_seens (
--   user_id integer NOT NULL,
--   category_id integer NOT NULL,
--   category_order integer DEFAULT 0 NOT NULL,
--   topic_id integer NOT NULL
-- );
-- ALTER TABLE ONLY community_user_category_last_seens
--   ADD CONSTRAINT community_user_category_last_seens_pkey PRIMARY KEY (user_id, category_id);
--
class UserCategoryLastSeens extends Model
  @primary_key: { "user_id", "category_id" }

  @relations: {
    {"user", belongs_to: "Users"}
    {"category", belongs_to: "Categories"}
    {"topic", belongs_to: "Topics"}
  }

  should_update: =>
    category = @get_category!
    @category_order < category\get_last_topic!.category_order



