
db = require "lapis.db"
import Model from require "community.model"

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

  @clear_post: (post) =>

