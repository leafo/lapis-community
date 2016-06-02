import use_test_env from require "lapis.spec"

factory = require "spec.factory"

describe "models.votes", ->
  use_test_env!

  import Users from require "spec.models"
  import Votes, Posts, Topics from require "spec.community_models"

  local current_user

  before_each ->
    current_user = factory.Users!

  it "should create vote for post", ->
    post = factory.Posts!
    Votes\create object: post, user_id: current_user.id, positive: false

  it "should vote on object", ->
    post = factory.Posts!
    Votes\vote post, current_user, true
    post\refresh!
    assert.same 1, post.up_votes_count
    assert.same 0, post.down_votes_count

    -- no-op
    Votes\vote post, current_user, true

    post\refresh!
    assert.same 1, post.up_votes_count
    assert.same 0, post.down_votes_count

    -- convert vote to down vote
    Votes\vote post, current_user, false

    post\refresh!
    assert.same 0, post.up_votes_count
    assert.same 1, post.down_votes_count





