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

  describe "purge", ->
    import Posts, Votes from require "spec.community_models"

    it "purges posts with no posts", ->
      user = factory.Users!
      cu = CommunityUsers\for_user user.id
      cu\purge_posts!

    it "purges votes with no posts", ->
      user = factory.Users!
      cu = CommunityUsers\for_user user.id
      cu\purge_votes!

    it "purges posts", ->
      user = factory.Users!

      cu = CommunityUsers\for_user user.id

      topic = factory.Topics!

      factory.Posts user_id: user.id, topic_id: topic.id
      factory.Posts user_id: user.id
      other_post = factory.Posts!

      cu\recount!
      assert.same 2, cu.posts_count
      assert.same 1, cu.topics_count

      cu\purge_posts!

      assert.same 1, Posts\count!

      assert.same 0, cu.posts_count
      assert.same 0, cu.topics_count

    it "purges votes", ->
      user = factory.Users!

      cu = CommunityUsers\for_user user.id
      factory.Votes user_id: user.id, positive: true
      factory.Votes user_id: user.id, positive: false
      other_vote = factory.Votes!

      cu\recount!
      assert.same 2, cu.votes_count, "community user votes_vount before purge"
      assert.same 3, Votes\count!, "total votes count before purge"

      cu\purge_votes!

      cu\refresh!
      assert.same 0, cu.votes_count, "community user votes_count after purge"
      assert.same 1, Votes\count!, "total votes count after purge"

  describe "posting rate", ->
    import ActivityLogs from require "spec.community_models"

    local user, cu
    before_each ->
      user = factory.Users!
      cu = CommunityUsers\for_user user.id

    it "gets rate from empty account", ->
      assert.same 0, cu\posting_rate 10

    it "gets rate from activity logs", ->
      for i=0,2
        t = db.raw "now() at time zone 'utc' - '#{i} minutes'::interval"

        ActivityLogs\create {
          user_id: user.id
          action: "create"
          object_type: "post"
          object_id: -1
          created_at: t
        }

        ActivityLogs\create {
          user_id: user.id
          action: "create"
          object_type: "topic"
          object_id: -1
          created_at: t
        }

        -- unrelated things
        -- edit action
        ActivityLogs\create {
          user_id: user.id
          action: "edit"
          object_type: "post"
          object_id: -1
          created_at: t
        }

        -- another user
        ActivityLogs\create {
          user_id: factory.Users!.id
          action: "create"
          object_type: "post"
          object_id: -1
          created_at: t
        }


      -- make sure it doesn't get short circuited
      cu\update last_post_at: db.raw "date_trunc('second', now() at time zone 'utc')"

      assert.same 6/10, cu\posting_rate 10
      assert.same 2, cu\posting_rate 1

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

