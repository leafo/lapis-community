
db = require "lapis.db"
import enum from require "lapis.db.model"
import Model from require "community.model"

import safe_insert from require "community.helpers.models"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_category_group_categories (
--   category_group_id integer NOT NULL,
--   category_id integer NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_category_group_categories
--   ADD CONSTRAINT community_category_group_categories_pkey PRIMARY KEY (category_group_id, category_id);
-- CREATE UNIQUE INDEX community_category_group_categories_category_id_idx ON community_category_group_categories USING btree (category_id);
--
class CategoryGroupCategories extends Model
  @timestamp: true
  @primary_key: {"category_group_id", "category_id"}

  @relations: {
    {"category_group", belongs_to: "CategoryGroups"}
    {"category", belongs_to: "Categories"}
  }

  @create: safe_insert


