
db = require "lapis.db"

import Flow from require "lapis.flow"
import Topics, Posts, CommunityUsers, ActivityLogs, PendingPosts from require "community.models"

import assert_valid from require "lapis.validate"
import assert_error, yield_error from require "lapis.application"

import require_current_user from require "community.helpers.app"
import is_empty_html from require "community.helpers.html"

limits = require "community.limits"

shapes = require "community.helpers.shapes"
types = require "lapis.validate.types"

class TopicsFlow extends Flow
  expose_assigns: true

  bans_flow: =>
    @load_topic!
    BansFlow = require "community.flows.bans"
    BansFlow @, @topic

  load_topic: =>
    return if @topic

    params = assert_valid @params, types.params_shape {
      {"topic_id", types.db_id}
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

  -- opts.force_pending -- always crated post as pending post, skip calling approval method
  new_topic: require_current_user (opts={}) =>
    CategoriesFlow = require "community.flows.categories"
    PollsFlow = require "community.flows.topic_polls"
    CategoriesFlow(@)\load_category!

    poll_flow = PollsFlow @

    new_topic = assert_valid @params.topic, types.params_shape {
      {"title", types.limited_text limits.MAX_TITLE_LEN }
      {"body", types.limited_text limits.MAX_BODY_LEN }
      {"body_format", shapes.default("html") * types.db_enum(Posts.body_formats)}
      {"tags", types.empty + types.limited_text(240) / @category\parse_tags }
      {"sticky", types.empty / false + types.any / true}
      {"locked", types.empty / false + types.any / true}
      {"poll", types.empty + types.table}
    }

    if new_topic.poll
      -- we do validation like this so we can have nice error messages
      {poll: new_poll} = assert_valid @params.topic, types.params_shape {
        {"poll", poll_flow\validate_params_shape!}
      }

      new_topic.poll = new_poll

      assert_error @category\allowed_to_create_poll(@current_user),
        "you can't create a poll in this category"

    body = assert_error Posts\filter_body new_topic.body, new_topic.body_format

    community_user = CommunityUsers\for_user @current_user

    assert_error @category\allowed_to_post_topic @current_user, @_req

    can_post, err, warning = community_user\allowed_to_post @category
    unless can_post
      @warning = warning
      yield_error err or "your account is not able to post at this time"

    sticky = false
    locked = false

    moderator = @category\allowed_to_moderate @current_user
    if moderator
      sticky = new_topic.sticky
      locked = new_topic.locked

    needs_approval, warning = if opts.force_pending
      true
    else
      @category\topic_needs_approval @current_user, {
        title: new_topic.title
        category_id: @category.id
        body_format: new_topic.body_format
        :body
      }

    create_params = {
      :needs_approval
      title: new_topic.title
      body_format: new_topic.body_format
      :body
      :sticky
      :locked
      tags: if new_topic.tags and next new_topic.tags
        [t.slug for t in *new_topic.tags]
    }

    if opts.before_create_callback
      opts.before_create_callback create_params

    if create_params.needs_approval
      @warning = warning

      metadata = {
        locked: if create_params.locked then create_params.locked
        sticky: if create_params.sticky then create_params.sticky
        topic_tags: create_params.tags
        note: create_params.approval_note
      }

      metadata = nil unless next metadata

      @pending_post = PendingPosts\create {
        user_id: @current_user.id
        category_id: @category.id
        title: create_params.title
        body_format: create_params.body_format
        body: create_params.body
        data: metadata
      }

      ActivityLogs\create {
        user_id: @current_user.id
        object: @pending_post
        action: "create_topic"
        data: {
          category_id: @category.id
        }
      }

      return true

    @topic = Topics\create {
      user_id: @current_user.id
      category_id: @category.id
      title: create_params.title
      tags: create_params.tags and db.array(create_params.tags)
      category_order: @category\next_topic_category_order!
      sticky: create_params.sticky
      locked: create_params.locked
    }

    @post = Posts\create {
      user_id: @current_user.id
      topic_id: @topic.id
      body_format: create_params.body_format
      body: create_params.body
    }

    @topic\increment_from_post @post, update_category_order: false
    @category\increment_from_topic @topic

    community_user\increment_from_post @post, true
    @topic\increment_participant @current_user

    @post\on_body_updated_callback @

    ActivityLogs\create {
      user_id: @current_user.id
      object: @topic
      action: "create"
    }

    if new_topic.poll
      poll_flow\set_poll @topic, new_topic.poll

    true


  -- this is called indirectly through delete post
  delete_topic: require_current_user =>
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
        params = assert_valid @params, types.params_shape {
          {"reason", types.empty + types.limited_text limits.MAX_BODY_LEN }
        }

        @write_moderation_log "topic.delete", params.reason

      true

  lock_topic: require_current_user =>
    @load_topic_for_moderation!

    params = assert_valid @params, types.params_shape {
      {"reason", types.empty + types.limited_text limits.MAX_BODY_LEN }
    }

    assert_error not @topic.locked, "topic is already locked"

    @topic\update locked: true
    @write_moderation_log "topic.lock", params.reason
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

    params = assert_valid @params, types.params_shape {
      {"reason", types.empty + types.limited_text limits.MAX_BODY_LEN }
    }

    @topic\update sticky: true
    @write_moderation_log "topic.stick", params.reason
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

    params = assert_valid @params, types.params_shape {
      {"reason", types.empty + types.limited_text limits.MAX_BODY_LEN }
    }

    assert_error @topic\hide!
    @write_moderation_log "topic.hide", params.reason
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

    params = assert_valid @params, types.params_shape {
      {"reason", types.empty + types.limited_text limits.MAX_BODY_LEN }
    }

    @topic\archive!
    @write_moderation_log "topic.archive", params.reason
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

    params = assert_valid @params, types.params_shape {
      {"target_category_id", types.db_id}
    }

    old_category_id = @topic.category_id

    @target_category = Categories\find params.target_category_id
    assert_error @target_category\allowed_to_moderate(@current_user),
      "invalid category"

    assert_error @topic\can_move_to @current_user, @target_category
    assert_error @topic\move_to_category @target_category

    @write_moderation_log "topic.move", nil, {
      category_id: old_category_id
      data: { target_category_id: @target_category.id }
    }

    true

