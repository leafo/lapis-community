db = require "lapis.db"

factory = require "spec.factory"

import Model from require "lapis.db.model"

import assert_has_queries, sorted_pairs from require "spec.helpers"

describe "models.topics", ->
  sorted_pairs!

  import Users from require "spec.models"

  import Categories, Moderators, CategoryMembers, Topics,
    Posts, Bans, CategoryTags from require "spec.community_models"

  it "should create a topic", ->
    factory.Topics!
    factory.Topics category: false

  it "gets topic post", ->
    topic = factory.Topics!
    post = factory.Posts topic_id: topic.id
    tp = topic\get_topic_post!
    assert.same tp.id, post.id

  it "gets category tags", ->
    topic = factory.Topics!
    category = topic\get_category!
    tag = factory.CategoryTags category_id: category.id

    topic\update tags: db.array { tag.slug, "other-thing"}
    tags = topic\get_tags!
    assert.same 1, #tags
    assert.same tag.label,tags[1].label

  describe "user_topic_last_seens", ->
    import UserTopicLastSeens from require "spec.community_models"

    it "has_unread", ->
      user = factory.Users!
      -- empty topic
      topic = factory.Topics!

      assert.false topic\has_unread user

      topic\update last_post_id: 10

      seen = UserTopicLastSeens\create {
        user_id: user.id
        topic_id: topic.id
        post_id: 10
      }

      topic\refresh!
      assert.false topic\has_unread user

      seen\update post_id: 9

      topic\refresh!
      assert.true topic\has_unread user

    describe "set_seen", ->
      it "should not mark for no last post", ->
        user = factory.Users!
        topic = factory.Topics!
        topic\set_seen user
        assert.same 0, UserTopicLastSeens\count!

      it "should mark topic last seen", ->
        user = factory.Users!
        topic = factory.Topics!
        post = factory.Posts topic_id: topic.id
        topic\increment_from_post post

        topic\set_seen user
        last_seen = unpack UserTopicLastSeens\select!
        assert.same user.id, last_seen.user_id
        assert.same topic.id, last_seen.topic_id
        assert.same post.id, last_seen.post_id

        -- noop
        topic\set_seen user

        -- update

        post2 = factory.Posts topic_id: topic.id
        topic\increment_from_post post2

        topic\set_seen user

        assert.same 1, UserTopicLastSeens\count!
        last_seen = unpack UserTopicLastSeens\select!

        assert.same user.id, last_seen.user_id
        assert.same topic.id, last_seen.topic_id
        assert.same post2.id, last_seen.post_id


  describe "subscriptions", ->
    import Subscriptions from require "spec.community_models"

    it "is_subscribed", ->
      -- owner is subscribed by default
      user = factory.Users!
      other_user = factory.Users!

      topic = factory.Topics user_id: user.id

      assert.true topic\is_subscribed user
      assert.false topic\is_subscribed other_user

      Subscriptions\create {
        object_type: "topic"
        object_id: topic.id
        user_id: user.id
        subscribed: false
      }

      Subscriptions\create {
        object_type: "topic"
        object_id: topic.id
        user_id: other_user.id
        subscribed: true
      }

      topic\refresh!

      assert.false topic\is_subscribed user
      assert.true topic\is_subscribed other_user

    it "gets subscription for topic", ->
      topic = factory.Topics!
      user = factory.Users!
      other_user = factory.Users!

      sub = Subscriptions\create {
        object_type: "topic"
        object_id: topic.id
        user_id: user.id
      }

      do -- unrealted subscriptions
        other_topic = factory.Topics!
        Subscriptions\create {
          object_type: "category"
          object_id: topic.id
          user_id: user.id
        }

        Subscriptions\create {
          object_type: "topic"
          object_id: other_topic.id
          user_id: user.id
        }

      assert.same sub, topic\find_subscription(user)
      assert.same sub, topic\with_user(user.id)\get_subscription!

      assert.nil topic\find_subscription(other_user)

  describe "bookmarks", ->
    import Bookmarks from require "spec.community_models"

    it "gets user's bookmark for topic", ->
      user = factory.Users!
      other_user = factory.Users!

      topic = factory.Topics!
      bookmark = factory.Bookmarks user_id: user.id, object_type: "topic", object_id: topic.id

      do -- unrelated bookmarks
        factory.Bookmarks user_id: user.id
        factory.Bookmarks user_id: other_user.id
        factory.Bookmarks object_type: "topic", object_id: topic.id

      -- both of these lines do the same thing
      assert.same bookmark, topic\with_user(user.id)\get_bookmark!
      assert.same bookmark, topic\get_bookmark(user)

      assert.nil topic\get_bookmark(other_user)

  describe "permissions with category", ->
    local category, topic, category_user, topic_user, some_user, mod_user
    before_each ->
      category_user = factory.Users!
      category = factory.Categories user_id: category_user.id
      topic_user = factory.Users!
      topic = factory.Topics category_id: category.id, user_id: topic_user.id

      some_user = factory.Users!
      mod = factory.Moderators object: topic\get_category!
      mod_user = mod\get_user!

    it "checks permissions of regular topic", ->
      assert.false topic\allowed_to_post nil
      assert.true topic\allowed_to_view nil
      assert.false topic\allowed_to_edit nil
      assert.false topic\allowed_to_moderate nil

      assert.true topic\allowed_to_post topic_user
      assert.true topic\allowed_to_view topic_user
      assert.true topic\allowed_to_edit topic_user
      assert.false topic\allowed_to_moderate topic_user

      assert.true topic\allowed_to_post some_user
      assert.true topic\allowed_to_view some_user
      assert.false topic\allowed_to_edit some_user
      assert.false topic\allowed_to_moderate some_user

      assert.true topic\allowed_to_post mod_user
      assert.true topic\allowed_to_view mod_user
      assert.true topic\allowed_to_edit mod_user
      assert.true topic\allowed_to_moderate mod_user

      assert.true topic\allowed_to_post category_user
      assert.true topic\allowed_to_view category_user
      assert.true topic\allowed_to_edit category_user
      assert.true topic\allowed_to_moderate category_user

    it "checks permissions of archived topic", ->
      -- archived topic
      topic\archive!
      topic = Topics\find topic.id -- clear memoized cache

      assert.false topic\allowed_to_post nil
      assert.true topic\allowed_to_view nil
      assert.false topic\allowed_to_edit nil
      assert.false topic\allowed_to_moderate nil

      assert.false topic\allowed_to_post topic_user
      assert.true topic\allowed_to_view topic_user
      assert.false topic\allowed_to_edit topic_user
      assert.false topic\allowed_to_moderate topic_user

      assert.false topic\allowed_to_post some_user
      assert.true topic\allowed_to_view some_user
      assert.false topic\allowed_to_edit some_user
      assert.false topic\allowed_to_moderate some_user

      assert.false topic\allowed_to_post mod_user
      assert.true topic\allowed_to_view mod_user
      assert.false topic\allowed_to_edit mod_user
      assert.true topic\allowed_to_moderate mod_user

      assert.false topic\allowed_to_post category_user
      assert.true topic\allowed_to_view category_user
      assert.false topic\allowed_to_edit category_user
      assert.true topic\allowed_to_moderate category_user

    it "checks  permissions of protected topic", ->
      topic\update protected: true

      assert.false topic\allowed_to_post nil
      assert.true topic\allowed_to_view nil
      assert.false topic\allowed_to_edit nil
      assert.false topic\allowed_to_moderate nil

      assert.true topic\allowed_to_post topic_user
      assert.true topic\allowed_to_view topic_user
      assert.false topic\allowed_to_edit topic_user
      assert.false topic\allowed_to_moderate topic_user

      assert.true topic\allowed_to_post some_user
      assert.true topic\allowed_to_view some_user
      assert.false topic\allowed_to_edit some_user
      assert.false topic\allowed_to_moderate some_user

      assert.true topic\allowed_to_post mod_user
      assert.true topic\allowed_to_view mod_user
      assert.false topic\allowed_to_edit mod_user
      assert.true topic\allowed_to_moderate mod_user

      assert.true topic\allowed_to_post category_user
      assert.true topic\allowed_to_view category_user
      assert.false topic\allowed_to_edit category_user
      assert.true topic\allowed_to_moderate category_user

    it "checks permissions for deleted topic", ->
      topic\update deleted: true

      assert.false topic\allowed_to_post nil
      assert.false topic\allowed_to_view nil
      assert.false topic\allowed_to_edit nil
      assert.false topic\allowed_to_moderate nil

      assert.false topic\allowed_to_post topic_user
      assert.false topic\allowed_to_view topic_user
      assert.false topic\allowed_to_edit topic_user
      assert.false topic\allowed_to_moderate topic_user

      assert.false topic\allowed_to_post some_user
      assert.false topic\allowed_to_view some_user
      assert.false topic\allowed_to_edit some_user
      assert.false topic\allowed_to_moderate some_user

      assert.false topic\allowed_to_post mod_user
      assert.false topic\allowed_to_view mod_user
      assert.false topic\allowed_to_edit mod_user
      assert.false topic\allowed_to_moderate mod_user

      assert.false topic\allowed_to_post category_user
      assert.false topic\allowed_to_view category_user
      assert.false topic\allowed_to_edit category_user
      assert.false topic\allowed_to_moderate category_user

  it "doesn't allow post when category is archived", ->
    category = factory.Categories user_id: factory.Users!.id
    category\update archived: true

    topic = factory.Topics category_id: category.id, locked: true

    user = factory.Users!
    topic_user = topic\get_user!
    category_user = category\get_user!

    assert.false topic\allowed_to_post user
    assert.false topic\allowed_to_post topic_user
    assert.false topic\allowed_to_post category_user

    assert.false topic\allowed_to_edit user
    assert.false topic\allowed_to_edit topic_user
    assert.false topic\allowed_to_edit category_user

  it "doesn't allow posts in locked topics", ->
    category_user = factory.Users!
    category = factory.Categories user_id: category_user.id

    topic = factory.Topics category_id: category.id, locked: true
    user = topic\get_user!

    assert.falsy topic\allowed_to_post category_user

  it "should check permissions of topic with members only category", ->
    category_user = factory.Users!
    category = factory.Categories {
      user_id: category_user.id
      membership_type: Categories.membership_types.members_only
    }

    topic = factory.Topics category_id: category.id

    other_user = factory.Users!
    assert.falsy topic\allowed_to_view other_user
    assert.falsy topic\allowed_to_post other_user

    member_user = factory.Users!
    factory.CategoryMembers user_id: member_user.id, category_id: category.id

    assert.truthy topic\allowed_to_view member_user
    assert.truthy topic\allowed_to_post member_user

  it "should check permissions of topic without category", ->
    topic = factory.Topics category: false

    user = topic\get_user!

    assert.truthy topic\allowed_to_post user
    assert.truthy topic\allowed_to_view user
    assert.truthy topic\allowed_to_edit user
    assert.falsy topic\allowed_to_moderate user

    other_user = factory.Users!

    assert.truthy topic\allowed_to_post other_user
    assert.truthy topic\allowed_to_view other_user
    assert.falsy topic\allowed_to_edit other_user
    assert.falsy topic\allowed_to_moderate other_user

  it "should set category order", ->
    category = factory.Categories!

    one = factory.Topics category_id: category.id
    two = factory.Topics category_id: category.id
    three = factory.Topics category_id: category.id

    assert.same 1, one.category_order
    assert.same 2, two.category_order
    assert.same 3, three.category_order

    post = factory.Posts topic_id: one.id
    one\increment_from_post post
    assert.same 4, one.category_order

    four = factory.Topics category_id: category.id
    assert.same 5, four.category_order

  describe "with votes", ->
    import Votes from require "spec.community_models"

    local category

    before_each ->
      category = factory.Categories {
        category_order_type: "topic_score"
      }

    it "creates topic with score ordering", ->
      topic = Topics\create {
        title: "hello world"
        category_order: category\next_topic_category_order!
      }

      assert.not.same 1, topic.category_order

    it "increments order when voted on", ->
      topic = factory.Topics {
        category_id: category.id
        category_order: category\next_topic_category_order!
      }

      initial = topic.category_order

      -- adding a post does not increment it
      post = factory.Posts {
        topic_id: topic.id
      }

      topic\increment_from_post post
      topic\refresh!

      assert.same initial, topic.category_order

      Votes\vote post, factory.Users!
      topic\refresh!

      assert initial < topic.category_order

  it "should check permission for banned user", ->
    topic = factory.Topics!
    banned_user = factory.Users!

    assert.falsy topic\get_ban banned_user
    factory.Bans object: topic, banned_user_id: banned_user.id
    topic\refresh!

    assert.truthy topic\get_ban banned_user

    assert.falsy topic\allowed_to_view banned_user
    assert.falsy topic\allowed_to_post banned_user

  it "should refresh last post id", ->
    topic = factory.Topics!
    factory.Posts topic_id: topic.id -- first
    post = factory.Posts topic_id: topic.id
    factory.Posts topic_id: topic.id, deleted: true

    topic\refresh_last_post!
    assert.same post.id, topic.last_post_id

  it "should refresh last post id to nil if there's only 1 post", ->
    topic = factory.Topics!
    factory.Posts topic_id: topic.id -- first

    topic\refresh_last_post!
    assert.same nil, topic.last_post_id

  it "should not include archived post when refreshing last", ->
    topic = factory.Topics!
    posts = for i=1,3
      with post = factory.Posts topic_id: topic.id
        topic\increment_from_post post

    posts[3]\update status: Posts.statuses.archived

    topic\refresh_last_post!
    assert.same posts[2].id, topic.last_post_id

  it "should not include archive and reset last post to nil", ->
    topic = factory.Topics!
    posts = for i=1,2
      with post = factory.Posts topic_id: topic.id
        topic\increment_from_post post

    posts[2]\update status: Posts.statuses.archived

    topic\refresh_last_post!
    assert.nil topic.last_post_id


  describe "delete", ->
    import PendingPosts, TopicParticipants, CommunityUsers, UserTopicLastSeens from require "spec.community_models"

    it "deletes a topic (soft by default)", ->
      topic = factory.Topics!
      topic\delete!
      topic\refresh!
      assert.true topic.deleted

    it "refreshes category when deleting topic", ->
      category = factory.Categories!
      t1 = factory.Topics :category
      t2 = factory.Topics :category

      category\refresh!
      assert.same t2.id, category.last_topic_id
      t2\delete!
      category\refresh!
      assert.same t1.id, category.last_topic_id

    it "hard deletes a topic", ->
      category = factory.Categories!
      user = factory.Users!
      topic = factory.Topics category_id: category.id, user_id: user.id
      post = factory.Posts topic_id: topic.id, user_id: user.id
      ban = factory.Bans object: topic

      topic\increment_from_post post
      category\increment_from_topic topic

      cu = CommunityUsers\for_user user
      cu\increment_from_post post, true

      cu\refresh!
      assert.same 1, cu.posts_count, "user posts_count before"
      assert.same 1, cu.topics_count, "user topics count before"

      category\refresh!
      assert.same 1, category.topics_count, "category topics before"
      assert.same 0, category.deleted_topics_count, "category deleted_topics_count before"
      TopicParticipants\increment topic.id, post.user_id
      topic\set_seen factory.Users!

      factory.PendingPosts topic: topic

      topic\hard_delete!

      assert.same 0, Topics\count!, "topics after delete"
      assert.same 0, Posts\count!, "posts count after delete"
      assert.same 0, PendingPosts\count!, "pending posts count after delete"
      assert.same 0, TopicParticipants\count!, "topic participants count after delete"
      assert.same 0, UserTopicLastSeens\count!, "user topic last seens after delete"

      assert.same 0, Bans\count!, "bans after delete"

      cu\refresh!
      assert.same 0, cu.posts_count, "user posts_count after hard"
      assert.same 0, cu.topics_count, "user topics count after hard"

      category\refresh!
      assert.same 0, category.topics_count, "category topics count after hard"
      assert.same 0, category.deleted_topics_count, "category deleted_topics_count after hard"

    it "hard deletes empty topic, verifying queries", ->
      topic = factory.Topics!
      i = db.interpolate_query
      assert_has_queries {
        i [[DELETE FROM "community_topics" WHERE "id" = ? RETURNING *]], topic.id
        i [[DELETE FROM "community_pending_posts" WHERE "topic_id" = ?]], topic.id
        i [[DELETE FROM "community_topic_participants" WHERE "topic_id" = ?]], topic.id
        i [[DELETE FROM "community_user_topic_last_seens" WHERE "topic_id" = ?]], topic.id
        i [[DELETE FROM "community_bans" WHERE "object_id" = ? AND "object_type" = 2]], topic.id
        i [[DELETE FROM "community_subscriptions" WHERE "object_id" = ? AND "object_type" = 1]], topic.id
        i [[DELETE FROM "community_bookmarks" WHERE "object_id" = ? AND "object_type" = 2]], topic.id
      }, ->
        topic\hard_delete!

    it "soft deletes, then hard deletes a topic", ->
      category = factory.Categories!
      user = factory.Users!
      topic = factory.Topics {
        category_id: category.id
        user_id: user.id
      }
      post = factory.Posts {
        topic_id: topic.id
        user_id: user.id
      }

      topic\increment_from_post post
      category\increment_from_topic topic

      cu = CommunityUsers\for_user user

      cu\increment_from_post post, true
      assert.same 1, cu.posts_count, "user posts_count before"
      assert.same 1, cu.topics_count, "user topics count before"

      category\refresh!
      assert.same 1, category.topics_count, "category topics count before"
      assert.same 0, category.deleted_topics_count, "category deleted_topics_count before"

      topic\soft_delete!

      cu\refresh!
      assert.same 1, cu.posts_count, "user posts_count after soft"
      assert.same 0, cu.topics_count, "user topics count after soft"

      category\refresh!
      assert.same 1, category.topics_count, "category topics count after soft"
      assert.same 1, category.deleted_topics_count, "category deleted_topics_count after soft"

      topic\hard_delete!

      cu\refresh!
      assert.same 0, cu.posts_count, "user posts_count after hard"
      assert.same 0, cu.topics_count, "user topics count after hard"

      category\refresh!
      assert.same 0, category.topics_count, "category topics count after hard"
      assert.same 0, category.deleted_topics_count, "category deleted_topics_count after hard"


  describe "renumber_posts", ->
    it "renumbers root posts", ->
      topic = factory.Topics!
      p1 = factory.Posts topic_id: topic.id
      p2 = factory.Posts topic_id: topic.id

      p2_1 = factory.Posts topic_id: topic.id, parent_post_id: p2.id
      p2_2 = factory.Posts topic_id: topic.id, parent_post_id: p2.id
      p2_3 = factory.Posts topic_id: topic.id, parent_post_id: p2.id

      p3 = factory.Posts topic_id: topic.id
      Model.delete p1

      topic\renumber_posts!

      posts = Posts\select "where depth = 1 order by post_number"
      assert.same {1,2}, [p.post_number for p in *posts]

      posts = Posts\select "where depth = 2 order by post_number"
      assert.same {1,2,3}, [p.post_number for p in *posts]

    it "renumbers nested posts posts", ->
      topic = factory.Topics!
      p1 = factory.Posts topic_id: topic.id
      p1_1 = factory.Posts topic_id: topic.id, parent_post_id: p1.id

      p2 = factory.Posts topic_id: topic.id
      p2_1 = factory.Posts topic_id: topic.id, parent_post_id: p2.id
      p2_2 = factory.Posts topic_id: topic.id, parent_post_id: p2.id
      p2_3 = factory.Posts topic_id: topic.id, parent_post_id: p2.id

      p3 = factory.Posts topic_id: topic.id

      Model.delete p2_2

      topic\renumber_posts p2

      posts = Posts\select "where depth = 1 order by post_number"
      assert.same {1,2,3}, [p.post_number for p in *posts]

      posts = Posts\select "where parent_post_id = ? order by post_number", p2.id
      assert.same {1,2}, [p.post_number for p in *posts]

    it "renumbers posts by created at", ->
      topic = factory.Topics!
      p1 = factory.Posts topic_id: topic.id, created_at: db.raw "date_trunc('second', now() - '2 minutes'::interval)"
      p2 = factory.Posts topic_id: topic.id, created_at: db.raw "date_trunc('second', now() - '5 minutes'::interval)"

      topic\renumber_posts nil, "created_at"

      p1\refresh!
      p2\refresh!

      assert.same {2,1}, {
        p1.post_number
        p2.post_number
      }

  describe "get_root_order_ranges", ->
    it "gets order ranges in empty topic", ->
      topic = factory.Topics!
      min, max = topic\get_root_order_ranges!

      assert.same nil, min
      assert.same nil, max

    it "gets order ranges topic with posts", ->
      topic = factory.Topics!
      p1 = factory.Posts topic_id: topic.id
      topic\increment_from_post p1

      p2 = factory.Posts topic_id: topic.id
      topic\increment_from_post p2

      for i=1,3
        pc = factory.Posts topic_id: topic.id, parent_post_id: p1.id
        topic\increment_from_post pc

      min, max = topic\get_root_order_ranges!

      assert.same 1, min
      assert.same 2, max

    it "ignores archive posts when getting order ranges", ->
      topic = factory.Topics!

      posts = for i=1,3
        with post = factory.Posts topic_id: topic.id
          topic\increment_from_post post

      posts[1]\archive!

      min, max = topic\get_root_order_ranges!
      assert.same 2, min
      assert.same 3, max

  describe "bans", ->
    relations = require "lapis.db.model.relations"

    it "preloads bans on many topics when user is not banned", ->
      user = factory.Users!
      topics = for i=1,3
        factory.Topics!

      Topics\preload_bans topics, user

      for t in *topics
        assert.same {ban: true}, t\with_user(user.id)[relations.LOADED_KEY]

    it "preloads bans", ->
      user = factory.Users!
      other_user = factory.Users!
      topics = for i=1,3
        factory.Topics!

      b1 = factory.Bans object: topics[1], banned_user_id: user.id
      b2 = factory.Bans object: topics[2], banned_user_id: other_user.id

      Topics\preload_bans topics, user

      for t in *topics
        assert.same {ban: true}, t\with_user(user.id)[relations.LOADED_KEY]

      assert.same b1, topics[1]\with_user(user.id).ban
      assert.same nil, topics[2]\with_user(user.id).ban
      assert.same nil, topics[3]\with_user(user.id).ban

  describe "subscribe", ->
    import Subscriptions from require "spec.community_models"

    fetch_subs = ->
      Subscriptions\select "order by user_id, object_type, object_id", fields: "user_id, object_type, object_id, subscribed"

    it "gets topic subscriptions", ->
      topic = factory.Topics!
      assert.same {}, topic\get_subscriptions!
      topic\refresh!
      Subscriptions\create {
        user_id: -1
        object_id: topic.id
        object_type: Subscriptions.object_types.topic
      }
      assert.same 1, #topic\get_subscriptions!

    it "subscribes user to topic", ->
      topic = factory.Topics!
      user = factory.Users!

      -- twice to test no-op
      for i=1,2
        topic\subscribe user
        assert.same {
          {
            object_type: Subscriptions.object_types.topic
            object_id: topic.id
            user_id: user.id
            subscribed: true
          }
        }, fetch_subs!


    it "topic creator subscribing is noop", ->
      topic = factory.Topics!
      user = topic\get_user!

      topic\subscribe user
      assert.same {}, fetch_subs!

    it "unsubscribe with no sub is noop", ->
      topic = factory.Topics!
      user = factory.Users!
      topic\unsubscribe user
      assert.same {}, fetch_subs!

    it "topic owner unsubscribes", ->
      topic = factory.Topics!
      user = topic\get_user!

      -- twice to test no-op
      for i=1,2
        topic\unsubscribe user
        assert.same {
          {
            object_type: Subscriptions.object_types.topic
            object_id: topic.id
            user_id: user.id
            subscribed: false
          }
        }, fetch_subs!

    it "regular user unsubscibes", ->
      topic = factory.Topics!
      user1 = factory.Users!
      user2 = factory.Users!

      topic\subscribe user1
      topic\subscribe user2

      topic\unsubscribe user1

      assert.same {
        {
          object_type: Subscriptions.object_types.topic
          object_id: topic.id
          user_id: user2.id
          subscribed: true
        }
      }, fetch_subs!

    it "gets notification targets for topic with no subs", ->
      topic = factory.Topics!
      targets = topic\notification_target_users!
      assert.same {topic.user_id}, [t.id for t in *targets]

    it "gets notification targets for topic with subs", ->
      topic = factory.Topics!
      user = factory.Users!
      topic\subscribe user

      targets = topic\notification_target_users!
      target_ids = [t.id for t in *targets]
      table.sort target_ids
      assert.same {topic.user_id, user.id}, target_ids

    it "gets empty notification targets when owner has unsubscribed", ->
      topic = factory.Topics!
      topic\unsubscribe topic\get_user!
      assert.same {}, topic\notification_target_users!

    it "gets targets for subs and unsubs", ->
      topic = factory.Topics!
      user = factory.Users!
      topic\unsubscribe topic\get_user!
      topic\subscribe user

      assert.same {user.id}, [t.id for t in *topic\notification_target_users!]

  describe "moving topic", ->

    import ModerationLogs, PostReports from require "spec.community_models"

    describe "can_move_to", ->
      it "doesn't let you move to same category", ->
        user = factory.Users!
        top = factory.Categories user_id: user.id
        topic = factory.Topics category: top

        assert.nil (topic\can_move_to user, top)

      it "allows move to adjacent", ->
        user = factory.Users!
        top = factory.Categories {
          user_id: user.id
          title: "top"
        }

        a = factory.Categories parent_category_id: top.id, user_id: user.id
        b = factory.Categories parent_category_id: top.id, user_id: user.id

        topic = factory.Topics category: a
        assert topic\can_move_to user, b

      it "allows move to subchild", ->
        user = factory.Users!
        top = factory.Categories {
          user_id: user.id
          title: "top"
        }

        a = factory.Categories parent_category_id: top.id, user_id: user.id

        topic = factory.Topics category: top
        assert topic\can_move_to user, a

      it "allows move to parent", ->
        user = factory.Users!
        top = factory.Categories {
          user_id: user.id
          title: "top"
        }

        a = factory.Categories parent_category_id: top.id, user_id: user.id

        topic = factory.Topics category: a
        assert topic\can_move_to user, top

      it "doesn't allow move to unrelated hierarchy", ->
        user = factory.Users!
        hierarchies = for i=1,2
          top = factory.Categories {
            user_id: user.id
            title: "top"
          }
          a = factory.Categories parent_category_id: top.id, user_id: user.id
          {top, a}

        topic = factory.Topics category: hierarchies[1][2]
        assert.nil (topic\can_move_to user, hierarchies[2][2])

    describe "movable_parent_category", ->
      it "finds top most parent", ->
        user = factory.Users!
        c = factory.Categories!
        c2 = factory.Categories parent_category_id: c.id, user_id: user.id
        c3 = factory.Categories parent_category_id: c2.id, user_id: user.id
        topic = factory.Topics category: c3
        found = topic\movable_parent_category user
        assert.same c2.id, found.id

    describe "with topic", ->
      local old_category, new_category, topic

      before_each ->
        old_category = factory.Categories!
        new_category = factory.Categories!
        topic = factory.Topics category: old_category

      it "should move basic topic", ->
        topic\move_to_category new_category
        topic\refresh!
        assert.same new_category.id, topic.category_id

        assert.same 0, old_category.topics_count
        assert.same 1, new_category.topics_count

      it "moves a topic with more relations", ->
        mod_log = ModerationLogs\create {
          object: topic
          category_id: old_category.id
          user_id: -1
          action: "hello.world"
          reason: "no reason"
        }

        other_mod_log = ModerationLogs\create {
          object: factory.Topics!
          category_id: -1
          user_id: -1
          action: "another.world"
          reason: "some reason"
        }

        report = factory.PostReports {
          post_id: factory.Posts(:topic).id
        }

        other_report = factory.PostReports!

        pending = factory.PendingPosts(:topic)
        other_pending = factory.PendingPosts!

        -- do the move
        topic\move_to_category new_category
        topic\refresh!
        assert.same new_category.id, topic.category_id

        mod_log\refresh!
        other_mod_log\refresh!

        assert.same new_category.id, mod_log.category_id
        assert.same -1, other_mod_log.category_id

        report\refresh!
        assert.same new_category.id, report.category_id

        old_other_report_category_id = other_report.category_id
        other_report\refresh!
        assert.same old_other_report_category_id, other_report.category_id

        pending\refresh!
        assert.same new_category.id, pending.category_id

        other_pending_category_id = other_pending.category_id
        other_pending\refresh!
        assert.same other_pending_category_id, other_pending.category_id

        topic\refresh!
        assert.same new_category.id, topic.category_id
        old_category\refresh!
        new_category\refresh!

        assert.nil old_category.last_topic_id
        assert.same topic.id, new_category.last_topic_id

        assert.same 0, old_category.topics_count
        assert.same 1, new_category.topics_count


  describe "calculate_score_category_order", ->
    local topic
    before_each ->
      topic = factory.Topics!
      post = factory.Posts {
        topic_id: topic.id
      }

      topic\increment_from_post post

    it "calculates score for topic with no votes", ->
      initial = topic\calculate_score_category_order!

      post = topic\get_topic_post!
      post\update up_votes_count: 10

      after = topic\calculate_score_category_order!
      assert initial < after

    it "updates rank adjustment", ->
      category = topic\get_category!
      category\update category_order_type: Categories.category_order_types.topic_score

      before = topic\calculate_score_category_order!

      assert topic\update_rank_adjustment 100
      assert 2 > math.abs 4009 - (topic.category_order - before)



