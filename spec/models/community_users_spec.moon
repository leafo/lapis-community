db = require "lapis.db"

factory = require "spec.factory"

import types from require "tableshape"

describe "models.community_users", ->
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

    it "purges posts from user with no posts", ->
      some_post = factory.Posts!

      user = factory.Users!
      cu = CommunityUsers\for_user user.id
      assert.same 0, (cu\purge_posts!)

      -- does not delete unrelated post
      assert_posts = types.assert types.shape {
        types.partial {
          id: some_post.id
        }
      }

      assert_posts Posts\select!


    it "purges votes from user with no votes", ->
      some_vote = factory.Votes!

      user = factory.Users!
      cu = CommunityUsers\for_user user.id
      assert.same 0, (cu\purge_votes!)

      -- does not delete unrelated vote
      assert_votes = types.assert types.shape {
        types.partial {
          user_id: some_vote.user_id
          object_type: some_vote.object_type
          object_id: some_vote.object_id
        }
      }

      assert_votes Votes\select!

    it "purges posts", ->
      user = factory.Users!

      cu = CommunityUsers\for_user user.id

      topic = factory.Topics permanent: true

      factory.Posts user_id: user.id, topic_id: topic.id
      factory.Posts user_id: user.id

      other_post = factory.Posts!
      factory.Posts user_id: user.id, topic_id: assert other_post.topic_id

      cu\recount!
      assert.same 3, cu.posts_count, "posts_count"
      assert.same 1, cu.topics_count, "topic topics_count"

      assert.same 3, (cu\purge_posts!), "total purged posts"

      -- TODO: we should also assert the remaining topics
      assert_posts = types.assert types.shape {
        types.partial {
          id: other_post.id
        }
      }

      assert_posts Posts\select!

      cu\refresh!

      assert_user = types.assert types.partial {
        topics_count: types.annotate 0
        posts_count: types.annotate 0
      }

      assert_user cu

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

    describe "purge reports", ->
      import PostReports from require "spec.community_models"

      it "with no reports", ->
        report = factory.PostReports!
        other_cu = factory.CommunityUsers!

        count = other_cu\purge_reports!
        assert.same 0, count

        assert_reports = types.assert types.shape {
          types.partial {
            id: report.id
            user_id: report.user_id
            body: report.body
          }
        }

        assert_reports PostReports\select!

      it "with no reports", ->
        cu = factory.CommunityUsers!

        report1 = factory.PostReports user_id: cu.user_id
        report2 = factory.PostReports user_id: cu.user_id
        report3 = factory.PostReports!

        count = cu\purge_reports!
        assert.same 2, count

        assert_reports = types.assert types.shape {
          types.partial {
            id: report3.id
            user_id: report3.user_id
            body: report3.body
          }
        }

        assert_reports PostReports\select!

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

      factory.Posts user_id: cu.user_id -- this is a topic post on a non pemanent topic
      factory.Topics user_id: cu.user_id -- this is an empty topic with no post

      perm_topic = factory.Topics permanent: true, user_id: cu.user_id -- pemanent topic should not increment topics
      factory.Posts topic_id: perm_topic.id, user_id: cu.user_id -- first post in perm topic

      other_post = factory.Posts!
      factory.Posts topic_id: other_post.topic_id, user_id: cu.user_id -- this is a post that is not topic post

      -- deleted post does not count
      factory.Posts topic_id: other_post.topic_id, user_id: cu.user_id, deleted: true

      CommunityUsers\recount user_id: cu.user_id
      cu\refresh!

      assert_counts cu, {
        posts_count: 3
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

  describe "allowed_to_post", ->
    local user, cu
    before_each ->
      user = factory.Users!
      cu = CommunityUsers\for_user user.id

    import Warnings from require "spec.community_models"

    it "checks category", ->
      topic = factory.Topics!
      assert.same true, cu\allowed_to_post topic

    it "checks blocked user", ->
      cu\update {
        posting_permission: CommunityUsers.posting_permissions.blocked
      }

      topic = factory.Topics!
      assert.same false, cu\allowed_to_post topic

    it "checks user with warning", ->
      topic = factory.Topics!

      -- this warning does not require approval, since it outright
      -- blocks
      w = Warnings\create {
        user_id: user.id
        restriction: Warnings.restrictions.block_posting
        duration: '1 day'
      }

      assert.same false, cu\allowed_to_post topic

      w\end_warning!
      cu\refresh!
      assert.same true, cu\allowed_to_post topic


      -- pending restriction does not affect allowed_to_post
      Warnings\create {
        user_id: user.id
        restriction: Warnings.restrictions.pending_posting
        duration: '1 day'
      }

      cu\refresh!
      assert.same true, cu\allowed_to_post topic

  describe "needs_approval_to_post", ->
    import Warnings, Categories from require "spec.community_models"

    local category

    before_each ->
      category = factory.Categories!

    it "with warning", ->
      user = factory.Users!
      cu = CommunityUsers\for_user user.id

      assert.same false, cu\needs_approval_to_post category

      -- this warning does not require approval, since it outright
      -- blocks
      Warnings\create {
        user_id: user.id
        restriction: Warnings.restrictions.block_posting
        duration: '1 day'
      }

      cu\refresh!
      assert.same false, cu\needs_approval_to_post category

      w = Warnings\create {
        user_id: user.id
        restriction: Warnings.restrictions.pending_posting
        duration: '1 day'
      }

      cu\refresh!
      assert.same true, cu\needs_approval_to_post category

      w\end_warning!

      cu\refresh!
      assert.same false, cu\needs_approval_to_post category

    it "with posting restriction", ->
      user = factory.Users!
      cu = CommunityUsers\for_user user.id

      assert.same false, cu\needs_approval_to_post category

      cu\update {
        posting_permission: CommunityUsers.posting_permissions.needs_approval
      }

      assert.same {true, nil}, {cu\needs_approval_to_post category}

      -- if usr can moderate object then they don't need approval
      own_category = factory.Categories user_id: cu.user_id
      assert.same {false}, {cu\needs_approval_to_post own_category}

  describe "blocks", ->
    import Blocks from require "community.models"

    -- serialize block
    s = (block) ->
      if block
        {
          blocking_user_id: block.blocking_user_id
          blocked_user_id: block.blocked_user_id
        }

    it "gets block", ->
      block = factory.Blocks!
      source_user = CommunityUsers\for_user block\get_blocking_user!
      dest_user = CommunityUsers\for_user block\get_blocked_user!

      assert.same s(block), s(source_user\get_block_given dest_user)
      assert.nil source_user\get_block_recieved dest_user

      assert.nil dest_user\get_block_given source_user
      assert.same s(block), s(dest_user\get_block_recieved source_user)


