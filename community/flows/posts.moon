import Flow from require "lapis.flow"
import Topics, Posts, PostEdits,
  CommunityUsers, ActivityLogs, PendingPosts from require "community.models"

db = require "lapis.db"
import assert_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import trim_filter, slugify from require "lapis.util"

import require_login from require "community.helpers.app"
import is_empty_html from require "community.helpers.html"

limits = require "community.limits"

shapes = require "community.helpers.shapes"
import types from require "tableshape"

class PostsFlow extends Flow
  expose_assigns: true

  load_post: =>
    return if @post

    params = shapes.assert_valid @params, {
      {"post_id", shapes.db_id}
    }

    @post = Posts\find params.post_id
    assert_error @post, "invalid post"

  new_post: require_login =>
    TopicsFlow = require "community.flows.topics"
    TopicsFlow(@)\load_topic!
    assert_error @topic\allowed_to_post @current_user, @_req

    params = shapes.assert_valid @params, {
      {"parent_post_id", shapes.db_id + shapes.empty }
    }

    new_post = shapes.assert_valid @params.post, {
      {"body", shapes.limited_text limits.MAX_BODY_LEN }
      {"body_format", shapes.db_enum(Posts.body_formats) + shapes.empty / Posts.body_formats.html}
    }

    body = assert_error Posts\filter_body new_post.body, new_post.body_format

    parent_post = if pid = params.parent_post_id
      assert_error Posts\find(pid), "invalid parent post"

    if parent_post
      assert_error parent_post.topic_id == @topic.id,
        "parent post doesn't belong to same topic"

      assert_error parent_post\allowed_to_reply(@current_user, @_req),
        "can't reply to post"

    if @topic\post_needs_approval!
      @pending_post = PendingPosts\create {
        user_id: @current_user.id
        topic_id: @topic.id
        category_id: @topic.category_id
        :body
        body_format: new_post.body_format
        parent_post_id: parent_post and parent_post.id
      }
    else
      @post = Posts\create {
        user_id: @current_user.id
        topic_id: @topic.id
        :body
        body_format: new_post.body_format
        :parent_post
      }

      @topic\increment_from_post @post
      CommunityUsers\for_user(@current_user)\increment "posts_count"
      @topic\increment_participant @current_user

      ActivityLogs\create {
        user_id: @current_user.id
        object: @post
        action: "create"
      }

      @post\refresh_search_index!

    true

  edit_post: require_login =>
    @load_post!
    assert_error @post\allowed_to_edit(@current_user, "edit"), "not allowed to edit"

    assert_valid @params, {
      {"post", type: "table"}
    }

    @topic = @post\get_topic!

    update_tags = @params.post.tags
    post_update = trim_filter @params.post
    assert_valid post_update, {
      {"body", exists: true, max_length: limits.MAX_BODY_LEN}
      {"body_format", optional: true, one_of: { "html", "markdown"} }
      {"reason", optional: true, max_length: limits.MAX_BODY_LEN}
    }

    body = assert_error Posts\filter_body post_update.body, post_update.body_format or "html"

    -- only if the body is different
    edited = if @post.body != body
      PostEdits\create {
        user_id: @current_user.id
        body_before: @post.body
        body_format: @post.body_format
        reason: post_update.reason
        post_id: @post.id
      }


      @post\update {
        :body
        edits_count: db.raw "edits_count + 1"
        last_edited_at: db.format_date!
        body_format: if post_update.body_format
          Posts.body_formats\for_db post_update.body_format
      }

      @post\refresh_search_index!

      true

    edited_title = if @post\is_topic_post! and not @topic.permanent
      assert_valid post_update, {
        {"title", optional: true, max_length: limits.MAX_TITLE_LEN}
        {"tags", optional: true, type: "string"}
      }

      opts = {}

      if post_update.title
        opts.title = post_update.title
        opts.slug = slugify post_update.title

      if update_tags
        category = @topic\get_category!
        tags = category\parse_tags post_update.tags
        opts.tags = if tags and next tags
          db.array [t.slug for t in *tags]
        else
          db.NULL

      import filter_update from require "community.helpers.models"
      topic_update = filter_update @topic, opts
      @topic\update topic_update
      topic_update.title and true

    if edited or edited_title
      @post\refresh_search_index!

    if edited
      ActivityLogs\create {
        user_id: @current_user.id
        object: @post
        action: "edit"
      }

    true

  delete_pending_post: require_login =>
    -- TODO: needs specs
    params = shapes.assert_valid @params, {
      {"post_id", shapes.db_id}
    }

    @pending_post = assert_error PendingPosts\find params.post_id
    assert_error @pending_post\allowed_to_edit(@current_user, "delete"), "not allowed to edit"
    @pending_post\delete!
    true

  delete_post: require_login =>
    @load_post!
    assert_error @post\allowed_to_edit(@current_user, "delete"), "not allowed to edit"

    @topic = @post\get_topic!

    if @post\is_topic_post! and not @topic.permanent
      TopicsFlow = require "community.flows.topics"
      TopicsFlow(@)\delete_topic!
      return true, "topic"

    mode = if @topic\allowed_to_moderate @current_user
      if @params.hard
        "hard"

    deleted, kind = @post\delete mode

    if deleted
      @topic\decrement_participant @post\get_user!
      unless kind == "hard"
        ActivityLogs\create {
          user_id: @current_user.id
          object: @post
          action: "delete"
        }

      true, kind

