import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import PendingPosts, Categories, Topics, Posts from require "community.models"

db = require "lapis.db"

factory = require "spec.factory"

describe "models.pending_posts", ->
  use_test_env!

  before_each ->
    truncate_tables Users, PendingPosts, Categories, Topics, Posts

  it "creates a pending post", ->
    factory.PendingPosts!

  it "promotes pending post", ->
    pending = factory.PendingPosts!
    pending\promote!

    assert.same 1, Posts\count!
    assert.same 0, PendingPosts\count!

  it "promotes pending post with parent", ->
    post = factory.Posts!
    topic = post\get_topic!

    pending = factory.PendingPosts parent_post_id: post.id, topic_id: topic.id
    pending\promote!

    assert.same 2, Posts\count!
    assert.same 0, PendingPosts\count!
