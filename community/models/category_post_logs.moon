
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
  @log_post: (post) =>
    topic = post\get_topic!
    return unless topic
    category = topic\get_category!
    return unless category
    ids = category\get_category_ids!
    return unless next ids
    ids = [db.escape_literal id for id in *ids]

    tbl = db.escape_identifier @table_name!
    db.query "
      insert into #{tbl} (post_id, category_id)
      select ?, foo.category_id from 
      (values (#{table.concat ids, "), ("})) as foo(category_id)
      where not exists(select 1 from #{tbl}
        where category_id = foo.category_id and post_id = ?)
    ", post.id, post.id

  @clear_post: (post) =>
    db.delete @table_name!, {
      post_id: post.id
    }

  @create: safe_insert
