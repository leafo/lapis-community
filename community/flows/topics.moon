
db = require "lapis.db"

import Flow from require "lapis.flow"
import Topics, Posts, CommunityUsers from require "community.models"

import assert_error from require "lapis.application"
import trim_filter from require "lapis.util"
import assert_valid from require "lapis.validate"

import require_login from require "community.helpers.app"

limits = require "community.limits"

class TopicsFlow extends Flow
  expose_assigns: true

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
    import TopicTags from require "community.models"

    @topic\set_tags @params.tags or ""
    true

  new_topic: require_login =>
    CategoriesFlow = require "community.flows.categories"
    CategoriesFlow(@)\load_category!
    assert_error @category\allowed_to_post @current_user

    assert_valid @params, {
      {"topic", type: "table"}
    }

    new_topic = trim_filter @params.topic
    assert_valid new_topic, {
      {"body", exists: true, max_length: limits.MAX_BODY_LEN}
      {"title", exists: true, max_length: limits.MAX_TITLE_LEN}
    }

    @topic = Topics\create {
      user_id: @current_user.id
      category_id: @category.id
      title: new_topic.title
      posts_count: 1
    }

    @post = Posts\create {
      user_id: @current_user.id
      topic_id: @topic.id
      body: new_topic.body
    }

    @category\update { topics_count: db.raw "topics_count + 1" }, timestamp: false
    CommunityUsers\for_user(@current_user)\increment "topics_count"
    @topic\increment_participant @current_user

    true

  delete_topic: require_login =>
    @load_topic!
    assert_error @topic\allowed_to_edit(@current_user), "not allowed to edit"
    @topic\delete!


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

