import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_category_tags (
--   id integer NOT NULL,
--   category_id integer NOT NULL,
--   slug character varying(255) NOT NULL,
--   label text,
--   color character varying(255),
--   tag_order integer DEFAULT 0 NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_category_tags
--   ADD CONSTRAINT community_category_tags_pkey PRIMARY KEY (id);
-- CREATE UNIQUE INDEX community_category_tags_category_id_slug_idx ON community_category_tags USING btree (category_id, slug);
--
class CategoryTags extends Model
  @timestamp: true

  @relations: {
    {"category", belongs_to: "Categories"}
  }

  @slugify: (str) =>
    str = str\gsub "%s+", "-"
    str = str\gsub "[^%w%-_%.]+", ""
    str = str\gsub "^[%-%._]+", ""
    str = str\gsub "[%-%._]+$", ""
    return nil if str == ""

    str = str\lower!
    str

  @create: (opts={}) =>
    if opts.label and not opts.slug
      opts.slug = @slugify opts.label
      return nil, "invalid label" unless opts.slug

    if opts.slug == opts.label
      opts.label = nil

    super opts

  name_for_display: =>
    @label or @slug
