import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Categories, Topics, Posts from require "community.models"

factory = require "spec.factory"

describe "posts", ->
  use_test_env!

  before_each ->
    truncate_tables Users, Categories, Topics, Posts

  it "should create a post", ->
    post = factory.Posts!

  it "should create a series of posts in same topic", ->
    posts = for i=1,5
      factory.Posts topic_id: 1

    assert.same [i for i=1,5], [p.post_number for p in *posts]

  it "should create correct post numbers for nested posts", ->
    root1 = factory.Posts topic_id: 1
    assert.same 1, root1.post_number

    root2 = factory.Posts topic_id: 1
    assert.same 2, root2.post_number

    child1 = factory.Posts topic_id: 1, parent_post: root1
    child2 = factory.Posts topic_id: 1, parent_post: root1

    assert.same 1, child1.post_number
    assert.same 2, child2.post_number

    other_child1 = factory.Posts topic_id: 1, parent_post: root2
    other_child2 = factory.Posts topic_id: 1, parent_post: root2

    assert.same 1, other_child1.post_number
    assert.same 2, other_child2.post_number

    root3 = factory.Posts topic_id: 1
    assert.same 3, root3.post_number

    current = root3
    for i=1,3
      current = factory.Posts topic_id: 1, parent_post: current
      assert.same 1, current.post_number


  describe "with post, topic, category", ->
    local post, topic, category

    before_each ->
      category = factory.Categories!
      topic = factory.Topics category_id: category.id
      post = factory.Posts topic_id: topic.id

    it "should check vote status on up down", ->
      category\update voting_type: Categories.voting_types.up_down
      other_user = factory.Users!

      assert.falsy post\allowed_to_vote nil
      assert.truthy post\allowed_to_vote other_user, "up"
      assert.truthy post\allowed_to_vote other_user, "down"

    it "should check vote status on up", ->
      category\update voting_type: Categories.voting_types.up
      other_user = factory.Users!

      assert.falsy post\allowed_to_vote nil
      assert.truthy post\allowed_to_vote other_user, "up"
      assert.falsy post\allowed_to_vote other_user, "down"

    it "should check vote status on disabled", ->
      category\update voting_type: Categories.voting_types.disabled
      other_user = factory.Users!

      assert.falsy post\allowed_to_vote nil
      assert.falsy post\allowed_to_vote other_user, "up"
      assert.falsy post\allowed_to_vote other_user, "down"

  it "should get mentions for post", ->
    factory.Users username: "mentioned_person"
    post = factory.Posts body: "hello @mentioned_person how are you doing @mentioned_person I am @nonexist"
    assert.same {"mentioned_person"}, [u.username for u in *post\get_mentioned_users!]

  it "should preload mentions for many posts", ->
    factory.Users username: "mentioned_person1"
    factory.Users username: "mentioned_person2"

    posts = {
      factory.Posts body: "hello @mentioned_person1 how are you doing @nonexist"
      factory.Posts body: "this is @mentioned_person2 how are you doing"
      factory.Posts body: "this is @mentioned_person2 how are you @mentioned_person1"
      factory.Posts body: "this is @nothing"
    }

    Posts\preload_mentioned_users posts

    usernames = for post in *posts
      [u.username for u in *post.mentioned_users]


    assert.same {"mentioned_person1"}, usernames[1]
    assert.same {"mentioned_person2"}, usernames[2]
    assert.same {"mentioned_person2", "mentioned_person1"}, usernames[3]
    assert.same {}, usernames[4]


