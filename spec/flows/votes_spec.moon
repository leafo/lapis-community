import use_test_env from require "lapis.spec"

factory = require "spec.factory"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

import TestApp from require "spec.helpers"

VotesFlow = require "community.flows.votes"

import Users from require "models"

class VotingApp extends TestApp
  @before_filter =>
    @current_user = Users\find assert @params.current_user_id, "missing user id"

  "/vote": capture_errors_json =>
    VotesFlow(@)\vote!
    json: { success: true }


describe "votes flow", ->
  use_test_env!

  local current_user

  import Users from require "spec.models"

  import
    Votes
    Posts
    Topics
    Categories
    CommunityUsers
    from require "spec.community_models"

  before_each ->
    current_user = factory.Users!

  it "should vote on a post", ->
    post = factory.Posts!
    res = VotingApp\get current_user, "/vote", {
      object_type: "post"
      object_id: post.id
      direction: "up"
    }

    assert.same { success: true }, res
    vote = assert unpack Votes\select!
    assert.same post.id, vote.object_id
    assert.same Votes.object_types.post, vote.object_type

    assert.same current_user.id, vote.user_id
    assert.same true, vote.positive

    post\refresh!

    assert.same 1, post.up_votes_count
    assert.same 0, post.down_votes_count

    cu = CommunityUsers\for_user(current_user)
    assert.same 1, cu.votes_count

  it "should update a vote with no changes", ->
    post = factory.Posts!
    res = VotingApp\get current_user, "/vote", {
      object_type: "post"
      object_id: post.id
      direction: "up"
    }

    assert.same { success: true }, res

    res = VotingApp\get current_user, "/vote", {
      object_type: "post"
      object_id: post.id
      direction: "up"
    }

    assert.same { success: true }, res

    vote = assert unpack Votes\select!
    assert.same post.id, vote.object_id
    assert.same Votes.object_types.post, vote.object_type

    assert.same current_user.id, vote.user_id
    assert.same true, vote.positive

    post\refresh!

    assert.same 1, post.up_votes_count
    assert.same 0, post.down_votes_count

    cu = CommunityUsers\for_user(current_user)
    assert.same 1, cu.votes_count

  it "should update a vote", ->
    vote = factory.Votes user_id: current_user.id

    res = VotingApp\get current_user, "/vote", {
      object_type: "post"
      object_id: vote.object_id
      direction: "down"
    }

    votes = Votes\select!
    assert.same 1, #votes
    new_vote = unpack votes

    assert.same false, new_vote.positive

    post = Posts\find new_vote.object_id
    assert.same 0, post.up_votes_count
    assert.same 1, post.down_votes_count

    -- still 0 because the factory didn't set initial value on counter
    cu = CommunityUsers\for_user(current_user)
    assert.same 0, cu.votes_count

  it "should remove vote on post", ->
    post = factory.Posts!
    _, vote = Votes\vote post, current_user

    res = VotingApp\get current_user, "/vote", {
      object_type: "post"
      object_id: post.id
      action: "remove"
    }

    assert.same 0, #Votes\select!

    post\refresh!
    assert.same 0, post.up_votes_count
    assert.same 0, post.up_votes_count

    cu = CommunityUsers\for_user current_user
    -- number off because factory didn't sync count to use
    assert.same -1, cu.votes_count


