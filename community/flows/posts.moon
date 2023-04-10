import Flow from require "lapis.flow"
import Topics, Posts, PostEdits,
  CommunityUsers, ActivityLogs, PendingPosts from require "community.models"

db = require "lapis.db"
import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import slugify from require "lapis.util"

import require_current_user from require "community.helpers.app"

limits = require "community.limits"
types = require "lapis.validate.types"

class PostsFlow extends Flow
  expose_assigns: true

  load_post: =>
    return if @post

    params = assert_valid @params, types.params_shape {
      {"post_id", types.db_id}
    }

    @post = Posts\find params.post_id
    assert_error @post, "invalid post"

  -- opts.force_pending -- always crated post as pending post, skip calling approval method
  -- returns true if post is created, will set either @post or @pending_post
  -- depending on the action performed, otherwise throws an error
  new_post: require_current_user (opts={}) =>
    TopicsFlow = require "community.flows.topics"
    TopicsFlow(@)\load_topic!

    community_user = CommunityUsers\for_user @current_user

    assert_error @topic\allowed_to_post @current_user, @_req

    can_post, posting_err, warning = community_user\allowed_to_post @topic
    unless can_post
      @warning = warning
      yield_error posting_err or "your account is not able to post at this time"

    {post: new_post, :parent_post_id} = assert_valid @params, types.params_shape {
      {"parent_post_id", types.db_id + types.empty }
      {"post", types.params_shape {
        {"body", types.limited_text limits.MAX_BODY_LEN }
        {"body_format", types.db_enum(Posts.body_formats) + types.empty / Posts.body_formats.html}
      }}
    }

    body = assert_error Posts\filter_body new_post.body, new_post.body_format

    parent_post = if pid = parent_post_id
      assert_error Posts\find(pid), "invalid parent post"

    if parent_post
      assert_error parent_post.topic_id == @topic.id,
        "parent post doesn't belong to same topic"

      assert_error parent_post\allowed_to_reply(@current_user, @_req),
        "can't reply to post"

      -- NOTE: this check is not part of allowed_to_reply to not cause the
      -- reply button to be hidden, revealing the block
      viewer = parent_post\with_viewing_user(@current_user.id)
      if block = viewer\get_block_received!
        @block = block
        yield_error "can't reply to post"


    needs_approval, warning = if opts.force_pending
      true
    else
      @topic\post_needs_approval @current_user, {
        :body
        topic_id: @topic.id
        body_format: new_post.body_format
        parent_post_id: parent_post and parent_post.id
      }

    create_params = {
      :needs_approval
      :body
      body_format: new_post.body_format
      parent_post_id: parent_post and parent_post.id
    }

    if opts.before_create_callback
      opts.before_create_callback create_params

    if create_params.needs_approval
      @warning = warning

      metadata = {
        note: create_params.approval_note
      }

      metadata = nil unless next metadata

      @pending_post = PendingPosts\create {
        user_id: @current_user.id
        topic_id: @topic.id
        category_id: @topic.category_id

        body: create_params.body
        body_format: create_params.body_format
        parent_post_id: create_params.parent_post_id

        data: metadata
      }

      ActivityLogs\create {
        user_id: @current_user.id
        object: @pending_post
        action: "create_post"
        data: {
          topic_id: @topic.id
          category_id: @topic.category_id
          parent_post_id: @pending_post.parent_post_id
        }
      }

      return true

    @post = Posts\create {
      user_id: @current_user.id
      topic_id: @topic.id

      body: create_params.body
      body_format: create_params.body_format
      parent_post_id: create_params.parent_post_id
    }

    @topic\increment_from_post @post
    community_user\increment_from_post @post
    @topic\increment_participant @current_user

    ActivityLogs\create {
      user_id: @current_user.id
      object: @post
      action: "create"
    }

    @post\on_body_updated_callback @

    true

  edit_post: require_current_user =>
    @load_post!
    assert_error @post\allowed_to_edit(@current_user, "edit"), "not allowed to edit"

    @topic = @post\get_topic!

    post_update = assert_valid @params.post, types.params_shape {
      {"body", types.limited_text limits.MAX_BODY_LEN }
      {"body_format", types.db_enum(Posts.body_formats) + types.empty / Posts.body_formats.html}
      {"reason", types.empty + types.limited_text limits.MAX_BODY_LEN }
    }

    body = assert_error Posts\filter_body post_update.body, post_update.body_format

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
        body_format: post_update.body_format
      }

      true

    edited_title = if @post\is_topic_post! and not @topic.permanent
      category = @topic\get_category!
      topic_update = assert_valid @params.post, types.params_shape {
        {"tags", types.empty + types.limited_text(240) / (category and category\parse_tags or nil) }
        {"title", types.nil + types.limited_text limits.MAX_TITLE_LEN }
      }

      if topic_update.title
        topic_update.slug = slugify topic_update.title

      if @params.post.tags -- only update tags if they were provided
        topic_update.tags = if topic_update.tags and next topic_update.tags
          db.array [t.slug for t in *topic_update.tags]
        else
          db.NULL

      import filter_update from require "community.helpers.models"
      topic_update = filter_update @topic, topic_update

      @topic\update topic_update
      topic_update.title and true

    if edited or edited_title
      @post\on_body_updated_callback @

    if edited
      ActivityLogs\create {
        user_id: @current_user.id
        object: @post
        action: "edit"
      }

    true

  delete_post: require_current_user =>
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

