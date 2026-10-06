import in_request from require "spec.flow_helpers"

factory = require "spec.factory"

import types from require "tableshape"

import instance_of from require "tableshape.moonscript"

describe "reports", ->
  local current_user

  import Users from require "spec.models"
  import PendingPosts, Topics, Posts, ActivityLogs, ModerationLogs, ModerationLogObjects from require "spec.community_models"

  before_each ->
    current_user = factory.Users!

  it "deletes", ->
    pending_post = factory.PendingPosts!
    PendingPostsFlow = require "community.flows.pending_posts"
    in_request {}, =>
      @current_user = current_user
      PendingPostsFlow(@)\delete_pending_post pending_post
  
  it "promotes", ->
    pending_post = factory.PendingPosts!
    PendingPostsFlow = require "community.flows.pending_posts"
    post = in_request {}, =>
      @current_user = current_user
      PendingPostsFlow(@)\promote_pending_post pending_post

    assert instance_of(Posts) post

    assert types.shape({
      types.partial {
        user_id: current_user.id
        action: ActivityLogs.actions.pending_post.promote
        object_type: ActivityLogs.object_types.pending_post
        object_id: pending_post.id
        data: types.partial {
          post_id: post.id
        }
      }
    }) ActivityLogs\select!

    assert types.shape({
      types.partial {
        user_id: current_user.id
        category_id: post\get_topic!.category_id
        object_type: ModerationLogs.object_types.post
        object_id: post.id
        action: "post.approve_pending"
        data: types.shape {
          pending_post_id: pending_post.id
        }
      }
    }) ModerationLogs\select!

  it "sets status", ->
    pending_post = factory.PendingPosts!
    PendingPostsFlow = require "community.flows.pending_posts"
    in_request {}, =>
      @current_user = current_user
      assert PendingPostsFlow(@)\set_pending_post_status pending_post, "ignored"

    assert.same PendingPosts.statuses.ignored, pending_post.status

    pending_post\delete!

    logs = ModerationLogs\select!
    assert types.shape({
      types.partial {
        user_id: current_user.id
        category_id: pending_post.category_id
        object_type: ModerationLogs.object_types.pending_post
        object_id: pending_post.id
        action: "pending_post.status(ignored)"
        data: types.shape {
          pending_post_id: pending_post.id
        }
      }
    }) logs

    assert.same {
      {ModerationLogObjects.object_types.user, pending_post.user_id}
      {ModerationLogObjects.object_types.topic, pending_post.topic_id}
    }, [{o.object_type, o.object_id} for o in *logs[1]\get_log_objects!]
  
