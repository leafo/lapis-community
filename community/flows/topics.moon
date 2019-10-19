
db = require "lapis.db"

import Flow from require "lapis.flow"
import Topics, Posts, CommunityUsers, ActivityLogs from require "community.models"

import assert_error from require "lapis.application"
import trim_filter from require "lapis.util"
import assert_valid from require "lapis.validate"

import require_login from require "community.helpers.app"
import is_empty_html from require "community.helpers.html"

limits = require "community.limits"

shapes = require "community.helpers.shapes"
import types from require "tableshape"

class TopicsFlow extends Flow
  expose_assigns: true

  bans_flow: =>
    @load_topic!
    BansFlow = require "community.flows.bans"
    BansFlow @, @topic

  load_topic: =>
    return if @topic

    params = shapes.assert_valid @params, {
      {"topic_id", shapes.db_id}
    }

    @topic = Topics\find params.topic_id
    assert_error @topic, "invalid topic"

  load_topic_for_moderation: =>
    @load_topic!
    assert_error @topic\allowed_to_moderate(@current_user), "invalid user"

  write_moderation_log: (action, reason, extra_params) =>
    @load_topic!

    import ModerationLogs from require "community.models"
    params = {
      user_id: @current_user.id
      object: @topic
      category_id: @topic.category_id
      :action
      :reason
    }

    if extra_params
      for k, v in pairs extra_params
        params[k] = v

    ModerationLogs\create params

  new_topic: require_login =>
    CategoriesFlow = require "community.flows.categories"
    CategoriesFlow(@)\load_category!
    assert_error @category\allowed_to_post_topic @current_user, @_req

    moderator = @category\allowed_to_moderate @current_user

    assert_valid @params, {
      {"topic", type: "table"}
    }


    new_topic = shapes.assert_valid @params.topic, {
      {"title", shapes.limited_text limits.MAX_TITLE_LEN }
      {"body", shapes.limited_text limits.MAX_BODY_LEN }
      {"body_format", shapes.db_enum(Posts.body_formats) + shapes.empty / Posts.body_formats.html}
      {"tags", shapes.empty + shapes.limited_text(240) / @category\parse_tags }
      {"sticky", shapes.empty / false + types.any / true}
      {"locked", shapes.empty / false + types.any / true}
    }

    body = assert_error Posts\filter_body new_topic.body, new_topic.body_format

    sticky = false
    locked = false

    if moderator
      sticky = new_topic.sticky
      locked = new_topic.locked

    @topic = Topics\create {
      user_id: @current_user.id
      category_id: @category.id
      title: new_topic.title
      tags: new_topic.tags and db.array([t.slug for t in *new_topic.tags])
      category_order: @category\next_topic_category_order!
      :sticky
      :locked
    }

    @post = Posts\create {
      user_id: @current_user.id
      topic_id: @topic.id
      body_format: new_topic.body_format
      :body
    }

    @topic\increment_from_post @post, update_category_order: false
    @category\increment_from_topic @topic

    CommunityUsers\for_user(@current_user)\increment "topics_count"
    @topic\increment_participant @current_user

    @post\refresh_search_index!

    ActivityLogs\create {
      user_id: @current_user.id
      object: @topic
      action: "create"
    }

    true


  -- this is called indirectly through delete post
  delete_topic: require_login =>
    @load_topic!
    assert_error @topic\allowed_to_edit(@current_user), "not allowed to edit"
    assert_error not @topic.permanent, "can't delete permanent topic"

    if @topic\delete!
      ActivityLogs\create {
        user_id: @current_user.id
        object: @topic
        action: "delete"
      }

      -- if we're a moderator then write to moderation log
      if @topic\allowed_to_moderate @current_user
        @write_moderation_log "topic.delete", @params.reason

      true

  lock_topic: require_login =>
    @load_topic_for_moderation!

    trim_filter @params
    assert_valid @params, {
      {"reason", optional: true, max_length: limits.MAX_BODY_LEN}
    }

    assert_error not @topic.locked, "topic is already locked"

    @topic\update locked: true
    @write_moderation_log "topic.lock", @params.reason
    true

  unlock_topic: =>
    @load_topic_for_moderation!

    assert_error @topic.locked, "topic is not locked"

    @topic\update locked: false
    @write_moderation_log "topic.unlock"
    true

  stick_topic: =>
    @load_topic_for_moderation!
    assert_error not @topic.sticky, "topic is already sticky"

    trim_filter @params
    assert_valid @params, {
      {"reason", optional: true, max_length: limits.MAX_BODY_LEN}
    }

    @topic\update sticky: true
    @write_moderation_log "topic.stick", @params.reason
    true

  unstick_topic: =>
    @load_topic_for_moderation!
    assert_error @topic.sticky, "topic is not sticky"

    @topic\update sticky: false
    @write_moderation_log "topic.unstick"
    true

  hide_topic: =>
    @load_topic_for_moderation!
    assert_error not @topic\is_hidden!, "topic is already hidden"
    assert_error not @topic\is_archived!, "can't hide archived topic"

    trim_filter @params
    assert_valid @params, {
      {"reason", optional: true, max_length: limits.MAX_BODY_LEN}
    }

    assert_error @topic\hide!
    @write_moderation_log "topic.hide", @params.reason
    true

  unhide_topic: =>
    @load_topic_for_moderation!
    assert_error @topic\is_hidden!, "topic is not hidden"

    @topic\set_status "default"
    @write_moderation_log "topic.unhide"
    true

  archive_topic: =>
    @load_topic_for_moderation!
    assert_error not @topic\is_archived!, "topic is already archived"

    trim_filter @params
    assert_valid @params, {
      {"reason", optional: true, max_length: limits.MAX_BODY_LEN}
    }

    @topic\archive!
    @write_moderation_log "topic.archive", @params.reason
    true

  unarchive_topic: =>
    @load_topic_for_moderation!
    assert_error @topic\is_archived!, "topic is not archived"

    @topic\set_status "default"
    @write_moderation_log "topic.unarchive"
    true

  move_topic: =>
    import Categories from require "community.models"
    @load_topic_for_moderation!

    assert_valid @params, {
      {"target_category_id", is_integer: true}
    }

    old_category_id = @topic.category_id

    @target_category = Categories\find @params.target_category_id
    assert_error @target_category\allowed_to_moderate(@current_user),
      "invalid category"

    assert_error @topic\can_move_to @current_user, @target_category
    assert_error @topic\move_to_category @target_category

    @write_moderation_log "topic.move", nil, {
      category_id: old_category_id
      data: { target_category_id: @target_category.id }
    }

    true

