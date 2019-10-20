import use_test_env from require "lapis.spec"

db = require "lapis.db"

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

  describe "increment_from_post", ->
    import Topics, Posts from require "spec.community_models"

    it "increments empty user object", ->
      user = factory.Users!
      cu = CommunityUsers\for_user user.id
      cu\increment_from_post factory.Posts!

      assert.same 1, cu.recent_posts_count
      assert.same 1, cu.posts_count
      assert.same 0, cu.topics_count
      assert.truthy cu.last_post_at

    it "increments recent post count", ->
      user = factory.Users!
      cu = CommunityUsers\for_user user.id

      for i=1,2
        cu\increment_from_post factory.Posts!

      assert.same 2, cu.recent_posts_count
      assert.same 2, cu.posts_count
      assert.same 0, cu.topics_count

    it "increments recent post count if it happened recently", ->
      user = factory.Users!
      cu = CommunityUsers\for_user user.id

      cu\update {
        recent_posts_count: 10
        last_post_at: db.raw db.interpolate_query "date_trunc('second', now() at time zone 'utc') - ?::interval + '1 minute'::interval", CommunityUsers.recent_threshold
      }

      cu\increment_from_post factory.Posts!
      assert.same 11, cu.recent_posts_count

    it "resets recent post count if it happened a while ago", ->
      user = factory.Users!
      cu = CommunityUsers\for_user user.id

      cu\update {
        recent_posts_count: 10
        last_post_at: db.raw db.interpolate_query "date_trunc('second', now() at time zone 'utc') - ?::interval - '5 minutes'::interval", CommunityUsers.recent_threshold
      }

      before = cu.last_post_at
      cu\increment_from_post factory.Posts!
      assert.same 1, cu.recent_posts_count

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

