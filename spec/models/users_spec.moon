import use_test_env from require "lapis.spec"

factory = require "spec.factory"

describe "models.users", ->
  use_test_env!

  import Users from require "spec.models"
  import CommunityUsers from require "spec.community_models"

  it "should create a user", ->
    factory.Users!

  it "creates a community user", ->
    user = factory.Users!
    cu = CommunityUsers\for_user user.id
    assert.same user.id, cu.user_id

  describe "recount", ->
    import Topics, Posts from require "spec.community_models"

    assert_counts = (cu, counts) ->
      cu\refresh!
      assert.same counts, {
        votes_count: cu.votes_count
        topics_count: cu.topics_count
        posts_count: cu.posts_count
      }

    it "recounts individual user", ->
      user = factory.Users!
      cu = CommunityUsers\for_user user.id
      CommunityUsers\recount user_id: cu.user_id
      cu\refresh!

      assert_counts cu, {
        posts_count: 0
        votes_count: 0
        topics_count: 0
      }

      factory.Posts user_id: cu.user_id
      factory.Topics user_id: cu.user_id

      CommunityUsers\recount user_id: cu.user_id
      cu\refresh!

      assert_counts cu, {
        posts_count: 1
        votes_count: 0
        topics_count: 2
      }

    it "doesn't include moderation log events in count", ->
      user = factory.Users!
      cu = CommunityUsers\for_user user.id

      factory.ModerationLogs user_id: cu.user_id
      assert.same 1, Posts\count!

      CommunityUsers\recount user_id: cu.user_id

      assert_counts cu, {
        posts_count: 0
        votes_count: 0
        topics_count: 0
      }

