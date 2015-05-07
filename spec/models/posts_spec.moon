import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"
import Users, Categories, Topics, Posts from require "models"

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

