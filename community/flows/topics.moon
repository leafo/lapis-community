
db = require "lapis.db"

import Flow from require "lapis.flow"
import Topics, Posts, CommunityUsers, ActivityLogs from require "community.models"

import assert_error from require "lapis.application"
import trim_filter from require "lapis.util"
import assert_valid from require "lapis.validate"

import require_login from require "community.helpers.app"
import is_empty_html from require "community.helpers.html"

limits = require "community.limits"

class TopicsFlow extends Flow
  expose_assigns: true

  bans_flow: =>
    @load_topic!
    BansFlow = require "community.flows.bans"
    BansFlow @, @topic

  load_topic: =>
    return if @topic

    assert_valid @params, {
      {"topic_id", is_integer: true}
    }

    @topic = Topics\find @params.topic_id
    assert_error @topic, "invalid topic"

  load_topic_for_moderation: =>
    @load_topic!
    assert_error @topic\allowed_to_moderate(@current_user), "invalid user"

  write_moderation_log: (action, reason) =>
    @load_topic!

    import ModerationLogs from require "community.models"
    ModerationLogs\create {
      user_id: @current_user.id
      object: @topic
      category_id: @topic.category_id
      :action
      :reason
    }

  set_tags: require_login =>
    @load_topic_for_moderation!
    error "fix me"
    true

  new_topic: require_login =>
    CategoriesFlow = require "community.flows.categories"
    CategoriesFlow(@)\load_category!
    assert_error @category\allowed_to_post_topic @current_user

    moderator = @category\allowed_to_moderate @current_user

    assert_valid @params, {
      {"topic", type: "table"}
    }

    new_topic = trim_filter @params.topic
    assert_valid new_topic, {
      {"body", exists: true, max_length: limits.MAX_BODY_LEN}
      {"title", exists: true, max_length: limits.MAX_TITLE_LEN}
    }

    assert_error not is_empty_html(new_topic.body), "body must be provided"

    sticky = false
    locked = false

    if moderator
      sticky = not not new_topic.sticky
      locked = not not new_topic.locked

    @topic = Topics\create {
      user_id: @current_user.id
      category_id: @category.id
      title: new_topic.title
      :sticky
      :locked
    }

    @post = Posts\create {
      user_id: @current_user.id
      topic_id: @topic.id
      body: new_topic.body
    }

    @topic\increment_from_post @post, update_category_order: false
    @category\increment_from_topic @topic

    CommunityUsers\for_user(@current_user)\increment "topics_count"
    @topic\increment_participant @current_user

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

