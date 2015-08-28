
import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_post_replies (
--   parent_post_id integer NOT NULL,
--   child_post_id integer NOT NULL
-- );
-- ALTER TABLE ONLY community_post_replies
--   ADD CONSTRAINT community_post_replies_pkey PRIMARY KEY (parent_post_id, child_post_id);
--
class PostReplies extends Model
  @primary_key: {"user_id", "post_id"}

