
import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_post_edits (
--   id integer NOT NULL,
--   post_id integer NOT NULL,
--   user_id integer NOT NULL,
--   body_before text NOT NULL,
--   reason text,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL,
--   body_format smallint DEFAULT 1 NOT NULL
-- );
-- ALTER TABLE ONLY community_post_edits
--   ADD CONSTRAINT community_post_edits_pkey PRIMARY KEY (id);
-- CREATE UNIQUE INDEX community_post_edits_post_id_id_idx ON community_post_edits USING btree (post_id, id);
--
class PostEdits extends Model
  @timestamp: true

  @relations: {
    {"post", belongs_to: "Posts"}
    {"user", belongs_to: "Users"}
  }

  @create: (opts={}) =>
    assert opts.post_id, "missing post_id"
    assert opts.user_id, "missing user_id"
    assert opts.body_before, "missing body_before"
    import Posts from require "community.models"
    opts.body_format or= Posts.body_formats.html
    super opts

