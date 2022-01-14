import in_request from require "spec.flow_helpers"

factory = require "spec.factory"

import types from require "tableshape"

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
    in_request {}, =>
      @current_user = current_user
      PendingPostsFlow(@)\promote_pending_post pending_post
  
