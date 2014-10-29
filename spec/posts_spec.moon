import load_test_server, close_test_server, request from require "lapis.spec.server"
import truncate_tables from require "lapis.spec.db"
import Users, Categories, Topics, Posts from require "models"

factory = require "spec.factory"

describe "posts", ->
  setup ->
    load_test_server!

  teardown ->
    close_test_server!

  before_each ->
    truncate_tables Users, Categories, Topics, Posts

  it "should create a post", ->
    post = factory.Posts!

  it "should create a series of posts in same topic", ->
    post1 = factory.Posts topic_id: 1
    post2 = factory.Posts topic_id: 1
    post3 = factory.Posts topic_id: 1
    post4 = factory.Posts topic_id: 1
    post5 = factory.Posts topic_id: 1

    assert.same 5, post5.post_number

