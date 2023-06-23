import in_request from require "spec.flow_helpers"

factory = require "spec.factory"

import types from require "tableshape"

import instance_of from require "tableshape.moonscript"

describe "reports", ->
  local current_user

  import Users from require "spec.models"
  import PendingPosts, Topics, Posts, ActivityLogs from require "spec.community_models"

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
  
