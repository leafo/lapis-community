db = require "lapis.db"
import enum from require "lapis.db.model"
import Model from require "community.model"

import slugify from require "lapis.util"

class Categories extends Model
  @timestamp: true

  @membership_types: enum {
    public: 1
    members_only: 2
  }

  @voting_types: enum {
    up_down: 1
    up: 2
    disabled: 3
  }

  @relations: {
    {"moderators", has_many: "CategoryModerators", where: { accepted: true }}
    {"user", belongs_to: "Users"}
    {"last_topic", belongs_to: "Topics"}
  }

  @create: (opts={}) =>
    assert opts.title, "missing title"
    opts.membership_type = @membership_types\for_db opts.membership_type or "public"
    opts.voting_type = @voting_types\for_db opts.voting_type or "up_down"
    opts.slug or= slugify opts.title

    Model.create @, opts

  @preload_last_topics: (categories) =>
    import Topics from require "community.models"
    Topics\include_in categories, "last_topic_id", {
      as: "last_topic"
    }

  allowed_to_post: (user) =>
    return false unless user
    @allowed_to_view user

  allowed_to_view: (user) =>
    can_view = switch @@membership_types[@membership_type]
      when "public"
        true
      when "members_only"
        return false unless user
        return true if @allowed_to_moderate user

        member = @find_member user
        member and member.accepted

    if can_view
      return false if @find_ban user

    can_view

  allowed_to_vote: (user, direction) =>
    return false unless user
    switch @voting_type
      when @@voting_types.up_down
        true
      when @@voting_types.up
        direction == "up"
      else
        false

  allowed_to_edit: (user) =>
    return nil unless user
    return true if user\is_admin!
    return true if user.id == @user_id
    false

  allowed_to_edit_moderators: (user) =>
    return nil unless user
    return true if user\is_admin!
    return true if user.id == @user_id
    if mod = @find_moderator user
      return true if mod.accepted and mod.admin

    false

  allowed_to_edit_members: (user) =>
    return nil unless user
    return @allowed_to_moderate user

  allowed_to_moderate: (user) =>
    return nil unless user
    return true if user\is_admin!
    return true if user.id == @user_id
    if mod = @find_moderator user
      return true if mod.accepted

    false

  find_moderator: (user) =>
    return nil unless user

    import CategoryModerators from require "community.models"
    CategoryModerators\find {
      category_id: @id
      user_id: user.id
    }

  find_member: (user) =>
    return nil unless user
    import CategoryMembers from require "community.models"

    CategoryMembers\find {
      category_id: @id
      user_id: user.id
    }

  find_ban: (user) =>
    return nil unless user
    import Bans from require "community.models"
    Bans\find_for_object @, user

  get_order_ranges: =>
    import Topics from require "community.models"

    res = db.query "
      select sticky, min(category_order), max(category_order)
      from #{db.escape_identifier Topics\table_name!}
      where category_id = ?
      group by sticky
    ", @id

    ranges = {
      sticky: {}
      regular: {}
    }

    for {:sticky, :min, :max} in *res
      r = ranges[sticky and "sticky" or "regular"]
      r.min = min
      r.max = max

    ranges

  available_vote_types: =>
    switch @voting_type
      when @@voting_types.up_down
        { up: true, down: true }
      when @@voting_types.up
        { up: true }
      else
        {}

  refresh_last_topic: =>
    import Topics from require "community.models"

    @update {
      last_topic_id: db.raw db.interpolate_query "(
        select id from #{db.escape_identifier Topics\table_name!} where category_id = ? and not deleted
        order by category_order desc
        limit 1
      )", @id
    }

  increment_from_topic: (topic) =>
    assert topic.category_id == @id

    @update {
      topics_count: db.raw "topics_count + 1"
      last_topic_id: topic.id
    }, timestamp: false

  increment_from_post: (post) =>
    @update {
      last_topic_id: post.topic_id
    }, timestamp: false

  @recount: =>
    import Topics from require "community.models"
    db.update @table_name!, {
      topics_count: db.raw "
        (select count(*) from #{db.escape_identifier Topics\table_name!}
          where category_id = #{db.escape_identifier @table_name!}.id)
      "
    }

