
import Model from require "community.model"

import concat from table

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_topic_tags (
--   topic_id integer NOT NULL,
--   slug character varying(255) NOT NULL,
--   label character varying(255),
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_topic_tags
--   ADD CONSTRAINT community_topic_tags_pkey PRIMARY KEY (topic_id, slug);
--
class TopicTags extends Model
  @primary_key: {"topic_id", "slug"}
  @timestamp: true

  @relations: {
    {"topic", belongs_to: "Topic"}
  }

  tag_parser = do
    lpeg = require "lpeg"
    import R, S, V, P from lpeg
    import C, Cs, Ct, Cmt, Cg, Cb, Cc from lpeg

    flatten_words = (words) -> concat words, " "

    sep = P","
    space = S" \t\r\n"
    white = space^0
    word = C (1 - (space + sep))^1
    words = Ct((word * white)^1) / flatten_words

    white * Ct (words^-1 * white * sep * white)^0 * words^-1 * -1

  @parse: (str) =>
    str = "" unless type(str) == "string"
    tag_parser\match(str) or {}

  @slugify: (str) =>
    str = str\gsub "%s+", "-"
    str = str\gsub "[^%w%-_%.]+", ""
    str = str\gsub "^[%-%._]+", ""
    str = str\gsub "[%-%._]+$", ""
    str = str\lower!
    str

  @create: (opts={}) =>
    assert opts.topic_id, "missing topic_id"
    assert opts.label, "missing label"
    opts.slug or= @slugify opts.label

    import safe_insert from require "community.helpers.models"
    safe_insert @, opts

  name_for_display: =>
    @label or @slug

