import use_test_env from require "lapis.spec"

factory = require "spec.factory"

describe "models.votes", ->
  use_test_env!

  import Users from require "spec.models"
  import Votes, Posts, Topics, CommunityUsers from require "spec.community_models"

  local current_user
  local snapshot

  before_each ->
    snapshot = assert\snapshot!
    current_user = factory.Users!

  after_each ->
    snapshot\revert!

  it "creates vote for post", ->
    post = factory.Posts!
    Votes\create object: post, user_id: current_user.id, positive: false

  it "vote object", ->
    post = factory.Posts!
    Votes\vote post, current_user, true
    post\refresh!
    assert.same 1, post.up_votes_count
    assert.same 0, post.down_votes_count

    vote = unpack Votes\select!
    assert.true vote.counted

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

  it "creates uncounted vote", ->
    -- uncounted because it's someone voting on their own post
    post = factory.Posts!
    user = post\get_user!

    for i=1,2 -- twice to test noop
      Votes\vote post, user, true
      post\refresh!

      assert.same 0, post.up_votes_count
      assert.same 0, post.down_votes_count

      vote = unpack Votes\select!
      assert.false vote.counted

    -- convert vote to down vote
    Votes\vote post, user, false

    post\refresh!

    assert.same 0, post.up_votes_count, "post.up_votes_count"
    assert.same 0, post.down_votes_count, "post.down_votes_count"

    vote = unpack Votes\select!
    assert.false vote.counted

    -- remove the vote
    Votes\unvote post, user

    post\refresh!

    assert.same 0, post.up_votes_count, "post.up_votes_count after removed"
    assert.same 0, post.down_votes_count, "post.down_votes_count after removed"

    assert.same 0, Votes\count!, "votes count"

  it "makes a vote with an adjusted score", ->
    post = factory.Posts!
    Votes\vote post, current_user
    vote = unpack Votes\select!
    assert.same 1, vote.score

    post\refresh!

    assert.same 1, post.up_votes_count
    assert.same 0, post.down_votes_count

    stub(CommunityUsers.__base, "get_vote_score").returns 2

    Votes\vote post, current_user

    vote = unpack Votes\select!
    assert.same 2, vote.score

    post\refresh!

    assert.same 2, post.up_votes_count
    assert.same 0, post.down_votes_count


  describe "update_counted", ->
    it "uncounts vote", ->
      post = factory.Posts!
      vote = Votes\vote post, current_user

      assert vote.counted, "vote is initially counted"
      post\refresh!

      assert.same 1, post.up_votes_count

      vote\update_counted false

      post\refresh!
      assert.same 0, post.up_votes_count

      vote\update_counted false

      post\refresh!
      assert.same 0, post.up_votes_count

    it "counts vote", ->
      post = factory.Posts!
      vote = Votes\vote post, current_user, true, {
        counted: false
      }

      assert not vote.counted, "vote initially uncounted"
      post\refresh!
      assert.same 0, post.up_votes_count, "up_votes_count is 0 initially "

      vote\update_counted true
      assert.true vote.counted, "vote changed to counted"

      post\refresh!
      assert.same 1, post.up_votes_count, "up_votes_count is 1 after update"




