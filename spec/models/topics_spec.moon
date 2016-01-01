import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

db = require "lapis.db"

import Users from require "models"
import
  Bans
  Categories
  CategoryMembers
  CategoryTags
  Moderators
  Posts
  Topics
  TopicSubscriptions
  UserTopicLastSeens
  from require "community.models"

factory = require "spec.factory"

import Model from require "lapis.db.model"

describe "models.topics", ->
  use_test_env!

  before_each ->
    truncate_tables Users, Categories, Moderators, CategoryMembers, Topics,
      Posts, Bans, UserTopicLastSeens, CategoryTags, TopicSubscriptions

  it "should create a topic", ->
    factory.Topics!
    factory.Topics category: false

  it "gets category tags", ->
    topic = factory.Topics!
    category = topic\get_category!
    tag = factory.CategoryTags category_id: category.id

    topic\update tags: db.array { tag.slug, "other-thing"}
    tags = topic\get_tags!
    assert.same 1, #tags
    assert.same tag.label,tags[1].label

  it "should check permissions of topic with category", ->
    category_user = factory.Users!
    category = factory.Categories user_id: category_user.id

    topic = factory.Topics category_id: category.id
    topic_user = topic\get_user!

    assert.truthy topic\allowed_to_post topic_user
    assert.truthy topic\allowed_to_view topic_user
    assert.truthy topic\allowed_to_edit topic_user
    assert.falsy topic\allowed_to_moderate topic_user

    some_user = factory.Users!

    assert.truthy topic\allowed_to_post some_user
    assert.truthy topic\allowed_to_view some_user
    assert.falsy topic\allowed_to_edit some_user
    assert.falsy topic\allowed_to_moderate some_user

    mod = factory.Moderators object: topic\get_category!
    mod_user = mod\get_user!

    assert.truthy topic\allowed_to_post mod_user
    assert.truthy topic\allowed_to_view mod_user
    assert.truthy topic\allowed_to_edit mod_user
    assert.truthy topic\allowed_to_moderate mod_user

    -- 

    assert.truthy topic\allowed_to_post category_user
    assert.truthy topic\allowed_to_view category_user
    assert.truthy topic\allowed_to_edit category_user
    assert.truthy topic\allowed_to_moderate category_user

    topic\archive!
    topic = Topics\find topic.id -- clear memoized cache

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
    one = factory.Topics category_id: 123
    two = factory.Topics category_id: 123
    three = factory.Topics category_id: 123

    assert.same 1, one.category_order
    assert.same 2, two.category_order
    assert.same 3, three.category_order

    post = factory.Posts topic_id: one.id
    one\increment_from_post post
    assert.same 4, one.category_order

    four = factory.Topics category_id: 123
    assert.same 5, four.category_order

  it "should check permission for banned user", ->
    topic = factory.Topics!
    banned_user = factory.Users!

    assert.falsy topic\find_ban banned_user
    factory.Bans object: topic, banned_user_id: banned_user.id
    assert.truthy topic\find_ban banned_user

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

  it "should not mark for no last post", ->
    user = factory.Users!
    topic = factory.Topics!
    topic\set_seen user

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

  describe "delete", ->
    it "deletes a topic", ->
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
    it "preloads bans on many topics when user is not banned", ->
      user = factory.Users!
      topics = for i=1,3
        factory.Topics!

      Topics\preload_bans topics, user
      for t in *topics
        assert.same {[user.id]: false}, t.user_bans

    it "preloads bans user", ->
      user = factory.Users!
      other_user = factory.Users!
      topics = for i=1,3
        factory.Topics!

      b1 = factory.Bans object: topics[1], banned_user_id: user.id
      b2 = factory.Bans object: topics[2], banned_user_id: other_user.id

      Topics\preload_bans topics, user

      assert.same {[user.id]: b1}, topics[1].user_bans
      assert.same {[user.id]: false}, topics[2].user_bans
      assert.same {[user.id]: false}, topics[3].user_bans


  describe "subscribe", ->
    fetch_subs = ->
      TopicSubscriptions\select "order by user_id, topic_id", fields: "user_id, topic_id, subscribed"

    it "gets topic subscriptions", ->
      topic = factory.Topics!
      assert.same {}, topic\get_subscriptions!
      topic\refresh!
      TopicSubscriptions\create user_id: -1, topic_id: topic.id
      assert.same 1, #topic\get_subscriptions!

    it "subscribes user to topic", ->
      topic = factory.Topics!
      user = factory.Users!

      -- twice to test no-op
      for i=1,2
        topic\subscribe user
        assert.same {
          {
            topic_id: topic.id
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
            topic_id: topic.id
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
          topic_id: topic.id
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
