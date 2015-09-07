import Flow from require "lapis.flow"
import Topics, Posts, PostEdits, CommunityUsers, ActivityLogs from require "community.models"

db = require "lapis.db"
import assert_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import trim_filter, slugify from require "lapis.util"

import require_login from require "community.helpers.app"
import is_empty_html from require "community.helpers.html"

limits = require "community.limits"

class PostsFlow extends Flow
  expose_assigns: true

  load_post: =>
    return if @post

    assert_valid @params, {
      {"post_id", is_integer: true }
    }

    @post = Posts\find @params.post_id
    assert_error @post, "invalid post"

  new_post: require_login =>
    TopicsFlow = require "community.flows.topics"
    TopicsFlow(@)\load_topic!
    assert_error @topic\allowed_to_post @current_user

    trim_filter @params
    assert_valid @params, {
      {"parent_post_id", optional: true, is_integer: true }
      {"post", type: "table"}
    }

    new_post = trim_filter @params.post
    assert_valid new_post, {
      {"body", type: "string", exists: true, max_length: limits.MAX_BODY_LEN}
    }

    assert_error not is_empty_html(new_post.body), "body must be provided"

    parent_post = if pid = @params.parent_post_id
      Posts\find pid

    if parent_post
      assert_error parent_post.topic_id == @topic.id,
        "topic id mismatch (#{parent_post.topic_id} != #{@topic.id})"

      assert_error parent_post\allowed_to_reply(@current_user),
        "can't reply to post"

    @post = Posts\create {
      user_id: @current_user.id
      topic_id: @topic.id
      body: new_post.body
      :parent_post
    }

    @topic\increment_from_post @post

    if category = @topic\get_category!
      category\increment_from_post @post

    CommunityUsers\for_user(@current_user)\increment "posts_count"
    @topic\increment_participant @current_user

    ActivityLogs\create {
      user_id: @current_user.id
      object: @post
      action: "create"
    }

    true

  edit_post: require_login =>
    @load_post!
    assert_error @post\allowed_to_edit(@current_user), "not allowed to edit"

    assert_valid @params, {
      {"post", type: "table"}
    }

    @topic = @post\get_topic!

    post_update = trim_filter @params.post
    assert_valid post_update, {
      {"body", exists: true, max_length: limits.MAX_BODY_LEN}
      {"reason", optional: true, max_length: limits.MAX_BODY_LEN}
    }

    assert_error not is_empty_html(post_update.body), "body must be provided"

    -- only if the body is different
    if @post.body != post_update.body
      PostEdits\create {
        user_id: @current_user.id
        body_before: @post.body
        reason: post_update.reason
        post_id: @post.id
      }

      @post\update {
        body: post_update.body
        edits_count: db.raw "edits_count + 1"
        last_edited_at: db.format_date!
      }

    if @post\is_topic_post! and not @topic.permanent
      assert_valid post_update, {
        {"title", optional: true, max_length: limits.MAX_TITLE_LEN}
      }

      if post_update.title
        @topic\update {
          title: post_update.title
          slug: slugify post_update.title
        }

    ActivityLogs\create {
      user_id: @current_user.id
      object: @post
      action: "edit"
    }

    true

  delete_post: require_login =>
    @load_post!
    assert_error @post\allowed_to_edit(@current_user), "not allowed to edit"

    @topic = @post\get_topic!

    if @post\is_topic_post! and not @topic.permanent
      TopicsFlow = require "community.flows.topics"
      TopicsFlow(@)\delete_topic!
      return true

    if @post\delete!
      topic = @post\get_topic!
      topic\decrement_participant @current_user

      if @post.id == topic.last_post_id
        topic\refresh_last_post!

      ActivityLogs\create {
        user_id: @current_user.id
        object: @post
        action: "delete"
      }

      true

