
db = require "lapis.db"
import Model from require "community.model"

import safe_insert from require "community.helpers.models"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_category_post_logs (
--   category_id integer NOT NULL,
--   post_id integer NOT NULL
-- );
-- ALTER TABLE ONLY community_category_post_logs
--   ADD CONSTRAINT community_category_post_logs_pkey PRIMARY KEY (category_id, post_id);
-- CREATE INDEX community_category_post_logs_post_id_idx ON community_category_post_logs USING btree (post_id);
--
class CategoryPostLogs extends Model
  @primary_key: {"category_id", "post_id"}

  @relations: {
    {"post", belongs_to: "Posts"}
    {"category", belongs_to: "Categories"}
  }

  @categories_to_log: (category) =>
    category_ids = [c.id for c in *category\get_ancestors! when c\should_log_posts!]
    if category\should_log_posts!
      table.insert category_ids, category.id

    category_ids

  @log_post: (post) =>
    topic = post\get_topic!
    return unless topic
    category = topic\get_category!
    return unless category

    category_ids = @categories_to_log category
    return unless next category_ids

    tuples = for id in *category_ids
      db.interpolate_query "?", db.list {post.id, id}

    tbl = db.escape_identifier @table_name!
    db.query "
      insert into #{tbl} (post_id, category_id)
      values  #{table.concat tuples, ", "}
      on conflict do nothing
    ", post.id

  @log_topic_posts: (topic) =>
    category = topic\get_category!
    return unless category

    category_ids = @categories_to_log category
    return unless next category_ids

    tuples = for id in *category_ids
      db.interpolate_query "?", db.list {id}

    import Posts from require "community.models"

    tbl = db.escape_identifier @table_name!
    db.query "
      insert into #{tbl} (post_id, category_id)
      select topic_post_ids.post_id, category_ids.category_id from
        (select id as post_id from #{db.escape_identifier Posts\table_name!}
          where topic_id = ? and status = 1 and not deleted) as topic_post_ids(post_id),
        (values #{table.concat tuples, ", "}) as category_ids(category_id)
      on conflict do nothing
    ", topic.id

  @clear_post: (post) =>
    db.delete @table_name!, {
      post_id: post.id
    }

  @clear_posts_for_topic: (topic) =>
    import Posts from require "community.models"

    db.delete @table_name!, {
      post_id: db.list {
        db.raw db.interpolate_query "
          select id from #{db.escape_identifier Posts\table_name!} where topic_id = ?
        ", topic.id
      }
    }

  @create: safe_insert
