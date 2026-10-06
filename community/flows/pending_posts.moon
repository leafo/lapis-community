db = require "lapis.db"

import Flow from require "lapis.flow"
import PendingPosts, ActivityLogs, ModerationLogs from require "community.models"

class PendingPosts extends Flow
  -- this is for when post creator is deleting their own post
  delete_pending_post: (pending_post) =>
    if pending_post\delete!
      ActivityLogs\create {
        user_id: @current_user.id
        object: pending_post
        action: "delete"
      }
      true

  create_moderation_log: (pending_post, opts) =>
    topic = opts.topic or pending_post\get_topic!
    category_id = pending_post.category_id or topic and topic.category_id

    log_objects = { pending_post\get_user! }
    table.insert log_objects, topic if topic

    ModerationLogs\create {
      user_id: @current_user.id
      object: opts.object
      action: opts.action
      category_id: category_id
      log_objects: log_objects
      data: {
        pending_post_id: pending_post.id
        title: pending_post.title
      }
    }

  -- this is for when a moderator promotes the post
  promote_pending_post: (pending_post) =>
    post, err = pending_post\promote @
    unless post
      return nil, err

    ActivityLogs\create {
      user_id: @current_user.id
      object: pending_post
      action: "promote"
      data: {
        post_id: post.id
      }
    }

    @create_moderation_log pending_post, {
      object: post
      topic: post\get_topic!
      action: "post.approve_pending"
    }

    post

  -- this is for when a moderator dismisses the post without promoting it
  set_pending_post_status: (pending_post, status) =>
    statuses = pending_post.__class.statuses
    status = statuses\for_db status

    return true if pending_post.status == status

    unless pending_post\update { :status }
      return nil, "failed to update status"

    @create_moderation_log pending_post, {
      object: pending_post
      action: "pending_post.status(#{statuses\to_name status})"
    }

    true
