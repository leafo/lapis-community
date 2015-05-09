
import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Categories, Topics, Posts, TopicTags, ModerationLogs, ModerationLogObjects from require "community.models"

import TestApp from require "spec.helpers"
import capture_errors_json from require "lapis.application"

factory = require "spec.factory"

class TopicsApp extends TestApp
  @require_user!

  @before_filter =>
    TopicsFlow = require "community.flows.topics"
    @flow = TopicsFlow @

  "/set-tags": capture_errors_json =>
    @flow\set_tags!
    json: { success: true }

  "/lock-topic": capture_errors_json =>
    @flow\lock_topic!
    json: { success: true }

  "/unlock-topic": capture_errors_json =>
    @flow\unlock_topic!
    json: { success: true }


describe "topic tags", ->
  use_test_env!

  local current_user, topic

  before_each ->
    truncate_tables Users, Categories, Topics, Posts, TopicTags, ModerationLogs, ModerationLogObjects
    current_user = factory.Users!

    category = factory.Categories user_id: current_user.id
    topic = factory.Topics category_id: category.id

  it "should set tags for topic", ->
    res = TopicsApp\get current_user, "/set-tags", {
      topic_id: topic.id
      tags: "hello,one,Two"
    }

    assert.truthy res.success
    assert.same 3, #topic\get_tags!

  it "should lock topic", ->
    res = TopicsApp\get current_user, "/lock-topic", {
      topic_id: topic.id
      reason: "this topic is stupid"
    }

    assert.truthy res.success

    logs = ModerationLogs\select!
    assert.same 1, #logs
    log = unpack logs

    assert.same current_user.id, log.user_id
    assert.same ModerationLogs.object_types.topic, log.object_type
    assert.same topic.id, log.object_id
    assert.same "topic.lock", log.action
    assert.same "this topic is stupid", log.reason

    assert.same 0, #ModerationLogObjects\select!

  it "should unlock topic", ->
    topic\update locked: true

    res = TopicsApp\get current_user, "/unlock-topic", {
      topic_id: topic.id
    }

    assert.truthy res.success

    logs = ModerationLogs\select!
    assert.same 1, #logs
    log = unpack logs

    assert.same current_user.id, log.user_id
    assert.same ModerationLogs.object_types.topic, log.object_type
    assert.same topic.id, log.object_id
    assert.same "topic.unlock", log.action

    assert.same 0, #ModerationLogObjects\select!

