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
    opts.category_order = @update_category_order_sql opts.category_id

    Model.create @, opts

  @update_category_order_sql: (category_id) =>
    return nil unless category_id

    db.raw db.interpolate_query "
      (select coalesce(max(category_order), 0) + 1
      from #{db.escape_identifier @table_name!}
      where category_id = ?)
    ", category_id

  @recount: =>
    import Posts from require "community.models"
    db.update @table_name!, {
      root_posts_count: db.raw "
        (select count(*) from #{db.escape_identifier Posts\table_name!}
          where topic_id = #{db.escape_identifier @table_name!}.id
          and depth = 1)
      "

      posts_count: db.raw "
        (select count(*) from #{db.escape_identifier Posts\table_name!}
          where topic_id = #{db.escape_identifier @table_name!}.id)
      "
    }

  allowed_to_post: (user) =>
    return false if @deleted
    @allowed_to_view user

  allowed_to_view: (user) =>
    return false if @deleted

    can_view = if @category_id
      @get_category!\allowed_to_view user
    else
      true

    if can_view
      return false if @find_ban user

    can_view

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

    import Categories from require "community.models"

    @get_category!\allowed_to_moderate user

  increment_participant: (user) =>
    return unless user
    import TopicParticipants from require "community.models"
    TopicParticipants\increment @id, user.id

  decrement_participant: (user) =>
    return unless user
    import TopicParticipants from require "community.models"
    TopicParticipants\decrement @id, user.id

  increment_post: (post) =>
    assert post.topic_id == @id, "invalid post sent to topic"

    @update {
      posts_count: db.raw "posts_count + 1"
      root_posts_count: if post.depth == 1
        db.raw "root_posts_count + 1"
      last_post_at: db.format_date!
      category_order: Topics\update_category_order_sql @category_id
    }, timestamp: false

  delete: =>
    import soft_delete from require "community.helpers.models"

    if soft_delete @
      if @user_id
        import CommunityUsers from require "community.models"
        CommunityUsers\for_user(@get_user!)\increment "topics_count", -1
      return true

    false

  get_tags: =>
    unless @tags
      import TopicTags from require "community.models"
      @tags = TopicTags\select "where topic_id = ?", @id

    @tags

  set_tags: (tags_str) =>
    import TopicTags from require "community.models"

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

  find_ban: (user) =>
    return nil unless user
    import Bans from require "community.models"
    Bans\find_for_object @, user

  find_recent_log: (action) =>
    import ModerationLogs from require "community.models"
    unpack ModerationLogs\select "
      where object_type = ? and object_id = ? and action = ?
      order by id desc
      limit 1
    ", ModerationLogs.object_types.topic, @id, action

  -- most recent log entry for locking
  get_lock_log: =>
    return unless @locked

    unless @lock_log
      @lock_log = @find_recent_log "topic.lock"

    @lock_log

  -- most recent log entry for sticking
  get_sticky_log: =>
    return unless @sticky

    unless @sticky_log
      import ModerationLogs from require "community.models"
      @sticky_log = @find_recent_log "topic.stick"

    @sticky_log

