db = require "lapis.db"
import Model from require "community.model"
import insert_on_conflict_update from require "community.helpers.models"

-- this needs some work
decode_html_entities = do
  entities = {
    amp: '&'
    nbsp: " "
    gt: '>'
    lt: '<'
    quot: '"'
    apos: "'"
    mdash: "—"
    rsquo: '’'
    trade: '™'
    "#x27": "'"
  }

  (str) ->
    (str\gsub '&(.-);', (tag) ->
      if entities[tag]
        entities[tag]
      elseif chr = tag\match "#(%d+)"
        chr = tonumber chr
        if chr >= 32 and chr <= 127
          string.char chr
        else
          "" -- TODO:
      -- elseif chr = tag\match "#[xX]([%da-fA-F]+)"
      -- TODO: add utf8 character support
      else
        '&'..tag..';')


class PostsSearch extends Model
  @primary_key: "post_id"
  @index_lang: "english"

  @relations: {
    {"post", belongs_to: "Posts"}
  }

  @index_post: (post) =>
    import Extractor from require "web_sanitize.html"
    extract_text = Extractor!
    topic = post\get_topic!

    body = decode_html_entities extract_text post.body

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
