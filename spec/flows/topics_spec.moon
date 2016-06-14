
import use_test_env from require "lapis.spec"

import TestApp from require "spec.helpers"
import capture_errors_json from require "lapis.application"

factory = require "spec.factory"

class TopicsApp extends TestApp
  @require_user!

  @before_filter =>
    TopicsFlow = require "community.flows.topics"
    @flow = TopicsFlow @

  "/lock-topic": capture_errors_json =>
    @flow\lock_topic!
    json: { success: true }

  "/unlock-topic": capture_errors_json =>
    @flow\unlock_topic!
    json: { success: true }

  "/stick-topic": capture_errors_json =>
    @flow\stick_topic!
    json: { success: true }

  "/unstick-topic": capture_errors_json =>
    @flow\unstick_topic!
    json: { success: true }

  "/archive-topic": capture_errors_json =>
    @flow\archive_topic!
    json: { success: true }

  "/unarchive-topic": capture_errors_json =>
    @flow\unarchive_topic!
    json: { success: true }

  "/move-topic": capture_errors_json =>
    @flow\move_topic!
    json: { success: true }

describe "topics", ->
  use_test_env!

  local current_user, topic

  import Users from require "spec.models"
  import Categories, Topics, Posts,
    ModerationLogs, ModerationLogObjects from require "spec.community_models"

  before_each ->
    current_user = factory.Users!
    category = factory.Categories user_id: current_user.id
    topic = factory.Topics category_id: category.id

  describe "lock", ->
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
      assert.same topic.category_id, log.category_id

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
      assert.same topic.category_id, log.category_id

      assert.same 0, #ModerationLogObjects\select!

    it "should not let random user lock topic", ->
      res = TopicsApp\get factory.Users!, "/lock-topic", {
        topic_id: topic.id
      }

      assert.truthy res.errors

    it "should not let random user unlock topic", ->
      topic\update locked: true
      res = TopicsApp\get factory.Users!, "/unlock-topic", {
        topic_id: topic.id
      }

      assert.truthy res.errors

  describe "stick", ->
    it "should stick topic", ->
      res = TopicsApp\get current_user, "/stick-topic", {
        topic_id: topic.id
        reason: " this topic is great and important "
      }

      assert.nil res.errors

      logs = ModerationLogs\select!
      assert.same 1, #logs
      log = unpack logs

      assert.same current_user.id, log.user_id
      assert.same ModerationLogs.object_types.topic, log.object_type
      assert.same topic.id, log.object_id
      assert.same "topic.stick", log.action
      assert.same "this topic is great and important", log.reason
      assert.same topic.category_id, log.category_id

      assert.same 0, #ModerationLogObjects\select!

    it "should unstick topic", ->
      topic\update sticky: true
      res = TopicsApp\get current_user, "/unstick-topic", {
        topic_id: topic.id
      }

      assert.nil res.errors

      logs = ModerationLogs\select!
      assert.same 1, #logs
      log = unpack logs

      assert.same current_user.id, log.user_id
      assert.same ModerationLogs.object_types.topic, log.object_type
      assert.same topic.id, log.object_id
      assert.same "topic.unstick", log.action
      assert.same topic.category_id, log.category_id

      assert.same 0, #ModerationLogObjects\select!

  describe "archive", ->
    it "archives topic", ->
      res = TopicsApp\get current_user, "/archive-topic", {
        topic_id: topic.id
        reason: "NOW ARCHIVED "
      }

      assert.nil res.errors

      topic\refresh!
      assert.true topic\is_archived!

      logs = ModerationLogs\select!
      assert.same 1, #logs
      log = unpack logs

      assert.same current_user.id, log.user_id
      assert.same ModerationLogs.object_types.topic, log.object_type
      assert.same topic.id, log.object_id
      assert.same "topic.archive", log.action
      assert.same "NOW ARCHIVED", log.reason
      assert.same topic.category_id, log.category_id

      assert.same 0, #ModerationLogObjects\select!


    it "unarchives topic", ->
      topic\archive!

      res = TopicsApp\get current_user, "/unarchive-topic", {
        topic_id: topic.id
      }

      assert.nil res.errors

      topic\refresh!
      assert.false topic\is_archived!

  describe "move", ->
    it "moves topic", ->
      old_cateory_id = topic.category_id
      other_category = factory.Categories {
        parent_category_id: topic.category_id
        user_id: current_user.id
      }

      res = TopicsApp\get current_user, "/move-topic", {
        topic_id: topic.id
        target_category_id: other_category.id
      }

      topic\refresh!
      assert.same other_category.id, topic.category_id

      logs = ModerationLogs\select!
      assert.same 1, #logs
      log = unpack logs

      assert.same topic.id, log.object_id
      assert.same ModerationLogs.object_types.topic, log.object_type
      assert.same "topic.move", log.action
      assert.same current_user.id, log.user_id
      assert.same old_cateory_id, log.category_id
      assert.same { target_category_id: other_category.id }, log.data

