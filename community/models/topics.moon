db = require "lapis.db"

import Model from require "community.model"
import slugify from require "lapis.util"

class Topics extends Model
  @timestamp: true

  @relations: {
    {"category", belongs_to: "Categories"}
    {"user", belongs_to: "Users"}
  }

  @create: (opts={}) =>
    if opts.title
      opts.slug or= slugify opts.title

    opts.last_post_at or= db.format_date!

    Model.create @, opts

  allowed_to_post: (user) =>
    return false if @deleted
    return false if @locked
    return nil, "no user" unless user
    true

  allowed_to_view: (user) =>
    return false if @deleted
    true

  allowed_to_edit: (user) =>
    return false if @deleted
    return false unless user
    return true if user.id == @user_id
    return true if user\is_admin!
    return true if @allowed_to_moderate user

    false

  allowed_to_moderate: (user) =>
    return false unless user
    return false unless @category_id

    import Categories from require "models"

    @get_category!\allowed_to_moderate user

  increment_participant: (user) =>
    return unless user
    import TopicParticipants from require "models"
    TopicParticipants\increment @id, user.id

  decrement_participant: (user) =>
    return unless user
    import TopicParticipants from require "models"
    TopicParticipants\decrement @id, user.id

  delete: =>
    import soft_delete from require "community.helpers.models"

    if soft_delete @
      if @user_id
        import CommunityUsers from require "models"
        CommunityUsers\for_user(@get_user!)\increment "topics_count", -1
      return true

    false

  get_tags: =>
    unless @tags
      import TopicTags from require "models"
      @tags = TopicTags\select "where topic_id = ?", @id

    @tags

  set_tags: (tags_str) =>
    import TopicTags from require "models"

    tags = TopicTags\parse tags_str
    old_tags = {tag.slug, true for tag in *@get_tags!}
    new_tags = {TopicTags\slugify(tag), tag for tag in *tags}

    -- filter and mark ones to add and ones to remove
    for slug in pairs new_tags
      if slug\match("^%-*$") or old_tags[slug]
        new_tags[slug] = nil
        old_tags[slug] = nil

    if next old_tags
      slugs = table.concat [db.escape_literal slug for slug in pairs old_tags], ","
      db.delete TopicTags\table_name!, "topic_id = ? and slug in (#{slugs})", @id

    for slug, label in pairs new_tags
      TopicTags\create {
        topic_id: @id
        :label
        :slug
      }

    @tags = nil -- clear cache
    true

  @recount: =>
    import Posts from require "models"
    db.update @table_name!, {
      root_posts_count: db.raw "
        (select count(*) from #{db.escape_identifier Posts\table_name!}
          where topic_id = #{db.escape_identifier @table_name!}.id
          and depth = 0)
      "

      posts_count: db.raw "
        (select count(*) from #{db.escape_identifier Posts\table_name!}
          where topic_id = #{db.escape_identifier @table_name!}.id)
      "
    }
