db = require "lapis.db"
import Model from require "community.model"
import insert_on_conflict_update from require "community.helpers.models"


-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_posts_search (
--   post_id integer NOT NULL,
--   topic_id integer NOT NULL,
--   category_id integer,
--   posted_at timestamp without time zone NOT NULL,
--   words tsvector
-- );
-- ALTER TABLE ONLY community_posts_search
--   ADD CONSTRAINT community_posts_search_pkey PRIMARY KEY (post_id);
-- CREATE INDEX community_posts_search_post_id_idx ON community_posts_search USING btree (post_id);
-- CREATE INDEX community_posts_search_words_idx ON community_posts_search USING gin (words);
--
class PostsSearch extends Model
  @primary_key: "post_id"
  @index_lang: "english"

  @relations: {
    {"post", belongs_to: "Posts"}
  }

  @index_post: (post) =>
    import Extractor from require "web_sanitize.html"
    extract_text = Extractor printable: true
    topic = post\get_topic!

    body = extract_text post.body

    title = if post\is_topic_post!
      topic.title

    words = if title
      db.interpolate_query "setweight(to_tsvector(?, ?), 'A') || setweight(to_tsvector(?, ?), 'B')",
        @index_lang,
        title,
        @index_lang,
        body
    else
      db.interpolate_query "to_tsvector(?, ?)", @index_lang, body

    insert_on_conflict_update @, {
      post_id: post.id
    }, {
      topic_id: topic.id
      category_id: topic.category_id
      words: db.raw words
      posted_at: post.created_at
    }

