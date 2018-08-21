
db = require "lapis.db"
import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_category_members (
--   user_id integer NOT NULL,
--   category_id integer NOT NULL,
--   accepted boolean DEFAULT false NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_category_members
--   ADD CONSTRAINT community_category_members_pkey PRIMARY KEY (user_id, category_id);
-- CREATE INDEX community_category_members_category_id_user_id_idx ON community_category_members USING btree (category_id, user_id) WHERE accepted;
--
class CategoryMembers extends Model
  @timestamp: true
  @primary_key: {"user_id", "category_id"}

  @relations: {
    {"user", belongs_to: "Users"}
    {"category", belongs_to: "Categories"}
  }

  @create: (opts={}) =>
    assert opts.user_id, "missing user id"
    assert opts.category_id, "missing category id"

    import insert_on_conflict_ignore from require "community.helpers.models"
    insert_on_conflict_ignore @, opts

