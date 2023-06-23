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

  -- this is for when a moderator promotes the post
  promote_pending_post: (pending_post) =>
    post, err = pending_post\promote!
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

    post

