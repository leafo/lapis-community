import use_test_env from require "lapis.spec"

factory = require "spec.factory"

describe "models.topic_participants", ->
  use_test_env!

  import Users from require "spec.models"
  import TopicParticipants from require "spec.community_models"

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
