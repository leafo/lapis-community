import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"
import Users, TopicParticipants from require "models"

factory = require "spec.factory"

describe "topic_participants", ->
  use_test_env!

  before_each ->
    truncate_tables TopicParticipants

  it "should participate a user", ->
    TopicParticipants\increment -1, 1
    ps = TopicParticipants\select!
    assert.same 1, #ps
    p = unpack ps

    assert.same -1, p.topic_id
    assert.same 1, p.user_id
    assert.same 1, p.posts_count

  it "should increment participant", ->
    TopicParticipants\increment -1, 1
    TopicParticipants\increment -1, 1

    ps = TopicParticipants\select!
    assert.same 1, #ps
    p = unpack ps

    assert.same -1, p.topic_id
    assert.same 1, p.user_id
    assert.same 2, p.posts_count

  it "should decrement participant", ->
    TopicParticipants\increment -1, 1
    TopicParticipants\increment -1, 1
    TopicParticipants\decrement -1, 1

    ps = TopicParticipants\select!
    assert.same 1, #ps
    p = unpack ps

    assert.same -1, p.topic_id
    assert.same 1, p.user_id
    assert.same 1, p.posts_count

  it "should decrement and delete participant", ->
    TopicParticipants\increment -1, 1
    TopicParticipants\decrement -1, 1

    ps = TopicParticipants\select!
    assert.same 0, #ps

  it "should un-participate an unincluded user", ->
    TopicParticipants\decrement -1, 1
    ps = TopicParticipants\select!
    assert.same 0, #ps
