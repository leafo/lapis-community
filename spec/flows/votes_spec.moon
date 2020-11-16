import use_test_env from require "lapis.spec"
import in_request from require "spec.flow_helpers"

factory = require "spec.factory"

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

  do_vote = (post) ->
    in_request { :post }, =>
      @current_user = current_user
      @flow("votes")\vote!

  it "votes positive on post", ->
    post = factory.Posts!
    assert do_vote {
      object_type: "post"
      object_id: post.id
      direction: "up"
    }

    vote = assert unpack Votes\select!
    assert.same post.id, vote.object_id, "object_id is post.id"
    assert.same Votes.object_types.post, vote.object_type, "object_type is post"

    assert.same current_user.id, vote.user_id, "vote user"
    assert.same true, vote.positive, "vote positive"

    post\refresh!

    assert.same 1, post.up_votes_count, "post up votes count"
    assert.same 0, post.down_votes_count, "post down_votes_count"

    cu = CommunityUsers\for_user(current_user)
    assert.same 1, cu.votes_count, "community user votes count"
    assert.same 0, cu.received_up_votes_count
    assert.same 0, cu.received_down_votes_count

    post_cu = CommunityUsers\for_user post\get_user!
    assert.same 0, post_cu.votes_count
    assert.same 1, post_cu.received_up_votes_count
    assert.same 0, post_cu.received_down_votes_count

  it "votes negative on post", ->
    post = factory.Posts!
    assert do_vote {
      object_type: "post"
      object_id: post.id
      direction: "down"
    }

    vote = assert unpack Votes\select!
    assert.same post.id, vote.object_id, "object_id is post.id"
    assert.same Votes.object_types.post, vote.object_type, "object_type is post"

    assert.same current_user.id, vote.user_id, "vote.user_id"
    assert.same false, vote.positive, "vote.positive"

    post\refresh!

    assert.same 0, post.up_votes_count, "post up votes count"
    assert.same 1, post.down_votes_count, "post down_votes_count"

    cu = CommunityUsers\for_user(current_user)
    assert.same 1, cu.votes_count, "community user votes count"
    assert.same 0, cu.received_up_votes_count
    assert.same 0, cu.received_down_votes_count

    post_cu = CommunityUsers\for_user post\get_user!
    assert.same 0, post_cu.votes_count
    assert.same 0, post_cu.received_up_votes_count
    assert.same 1, post_cu.received_down_votes_count

  it "updates a vote with no changes", ->
    post = factory.Posts!

    assert do_vote {
      object_type: "post"
      object_id: post.id
      direction: "up"
    }


    assert do_vote {
      object_type: "post"
      object_id: post.id
      direction: "up"
    }

    vote = assert unpack Votes\select!
    assert.same post.id, vote.object_id, "vote object_id"
    assert.same Votes.object_types.post, vote.object_type, "vote object_type"

    assert.same current_user.id, vote.user_id, "vote user_id"
    assert.same true, vote.positive, "vote positive"

    post\refresh!

    assert.same 1, post.up_votes_count, "post.up_votes_count"
    assert.same 0, post.down_votes_count, "post.down_votes_count"

    cu = CommunityUsers\for_user current_user
    assert.same 1, cu.votes_count
    assert.same 0, cu.received_up_votes_count
    assert.same 0, cu.received_down_votes_count

    post_cu = CommunityUsers\for_user post\get_user!
    assert.same 0, post_cu.votes_count
    assert.same 1, post_cu.received_up_votes_count
    assert.same 0, post_cu.received_down_votes_count

  it "updates a vote", ->
    post = factory.Posts!
    -- create the vote
    vote = Votes\vote post, current_user

    -- update the vote
    do_vote {
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

    cu = CommunityUsers\for_user current_user
    assert.same 1, cu.votes_count
    assert.same 0, cu.received_up_votes_count
    assert.same 0, cu.received_down_votes_count

    post_cu = CommunityUsers\for_user post\get_user!
    assert.same 0, post_cu.votes_count
    assert.same 0, post_cu.received_up_votes_count
    assert.same 1, post_cu.received_down_votes_count

  it "removes positive vote on post", ->
    post = factory.Posts!
    vote = Votes\vote post, current_user

    cu = CommunityUsers\for_user current_user
    assert.same 1, cu.votes_count, "community user votes_count before remove"
    assert.same 0, cu.received_up_votes_count
    assert.same 0, cu.received_down_votes_count

    post_cu = CommunityUsers\for_user post\get_user!

    assert.same 0, post_cu.votes_count, "post's community user votes_count before remove"
    assert.same 1, post_cu.received_up_votes_count
    assert.same 0, post_cu.received_down_votes_count

    post\refresh!
    assert.same 1, post.up_votes_count, "post up_votes_count"
    assert.same 0, post.down_votes_count, "post down_votes_count"

    do_vote {
      object_type: "post"
      object_id: post.id
      action: "remove"
    }

    assert.same 0, #Votes\select!

    post\refresh!
    assert.same 0, post.up_votes_count, "post up_votes_count"
    assert.same 0, post.down_votes_count, "post down_votes_count"

    cu = CommunityUsers\for_user current_user
    assert.same 0, cu.votes_count, "community user votes_count"
    assert.same 0, cu.received_up_votes_count
    assert.same 0, cu.received_down_votes_count

    post_cu = CommunityUsers\for_user post\get_user!
    assert.same 0, post_cu.votes_count, "post's community user votes_count"
    assert.same 0, post_cu.received_up_votes_count
    assert.same 0, post_cu.received_down_votes_count

  it "removes negative vote on post", ->
    post = factory.Posts!
    _, vote = Votes\vote post, current_user, false

    cu = CommunityUsers\for_user current_user
    assert.same 1, cu.votes_count, "community user votes_count before remove"
    assert.same 0, cu.received_up_votes_count
    assert.same 0, cu.received_down_votes_count

    post_cu = CommunityUsers\for_user post\get_user!

    assert.same 0, post_cu.votes_count, "post's community user votes_count before remove"
    assert.same 0, post_cu.received_up_votes_count
    assert.same 1, post_cu.received_down_votes_count

    post\refresh!
    assert.same 0, post.up_votes_count, "post up_votes_count"
    assert.same 1, post.down_votes_count, "post down_votes_count"

    do_vote {
      object_type: "post"
      object_id: post.id
      action: "remove"
    }

    assert.same 0, #Votes\select!

    post\refresh!
    assert.same 0, post.up_votes_count, "post up_votes_count"
    assert.same 0, post.down_votes_count, "post down_votes_count"

    cu = CommunityUsers\for_user current_user
    assert.same 0, cu.votes_count, "community user votes_count"
    assert.same 0, cu.received_up_votes_count
    assert.same 0, cu.received_down_votes_count

    post_cu = CommunityUsers\for_user post\get_user!

    assert.same 0, post_cu.votes_count, "post's community user votes_count"
    assert.same 0, post_cu.received_up_votes_count
    assert.same 0, post_cu.received_down_votes_count
