import in_request from require "spec.flow_helpers"

import types from require "tableshape"

factory = require "spec.factory"

describe "topics", ->
  local current_user, topic

  import Users from require "spec.models"
  import Categories, Topics, Posts,
    ModerationLogs, ModerationLogObjects from require "spec.community_models"

  before_each ->
    current_user = factory.Users!
    category = factory.Categories user_id: current_user.id
    topic = factory.Topics category_id: category.id

  method = (m, post, user=current_user) ->
    in_request {:post}, =>
      @current_user = user
      f = @flow("topics")
      f[m](f) or "noop"

  describe "lock", ->
    it "should lock topic", ->
      assert method "lock_topic", {
        topic_id: topic.id
        reason: "this topic is stupid"
      }

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

      assert method "unlock_topic", {
        topic_id: topic.id
      }

      logs = ModerationLogs\select!
      assert.same 1, #logs
      log = unpack logs

      assert.same current_user.id, log.user_id
      assert.same ModerationLogs.object_types.topic, log.object_type
      assert.same topic.id, log.object_id
      assert.same "topic.unlock", log.action
      assert.same topic.category_id, log.category_id

      assert.same 0, #ModerationLogObjects\select!

    it "doesn't let random user lock topic", ->
      assert.has_error(
        ->
          method "lock_topic", {
            topic_id: topic.id
          }, factory.Users!
        { message: { "invalid user" } }
      )

    it "should not let random user unlock topic", ->
      topic\update locked: true

      assert.has_error(
        ->
          method "unlock_topic", {
            topic_id: topic.id
          }, factory.Users!
        { message: { "invalid user" } }
      )

  describe "stick", ->
    it "should stick topic", ->
      assert method "stick_topic", {
        topic_id: topic.id
        reason: " this topic is great and important "
      }

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
      method "unstick_topic", {
        topic_id: topic.id
      }

      logs = ModerationLogs\select!
      assert.same 1, #logs
      log = unpack logs

      assert.same current_user.id, log.user_id
      assert.same ModerationLogs.object_types.topic, log.object_type
      assert.same topic.id, log.object_id
      assert.same "topic.unstick", log.action
      assert.same topic.category_id, log.category_id

      assert.same 0, #ModerationLogObjects\select!

  describe "hide", ->
    it "hides topic", ->
      assert method "hide_topic", {
        topic_id: topic.id
        reason: " HIDDEN Topic "
      }

      topic\refresh!
      assert.true topic\is_hidden!
      assert.false topic\is_archived!
      assert.false topic\is_default!

      assert types.shape({
        types.shape {
          user_id: current_user.id
          object_type: ModerationLogs.object_types.topic
          object_id: topic.id
          action: "topic.hide"
          reason: "HIDDEN Topic"
          category_id: topic.category_id
        }, open: true
      }) ModerationLogs\select!

    it "unhides topic", ->
      topic\hide!

      assert method "unhide_topic", {
        topic_id: topic.id
      }

      topic\refresh!
      assert.false topic\is_hidden!

      assert types.shape({
        types.shape {
          user_id: current_user.id
          object_type: ModerationLogs.object_types.topic
          object_id: topic.id
          action: "topic.unhide"
          category_id: topic.category_id
        }, open: true
      }) ModerationLogs\select!


  describe "archive", ->
    it "archives topic", ->
      assert method "archive_topic", {
        topic_id: topic.id
        reason: "NOW ARCHIVED "
      }

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

      assert method "unarchive_topic", {
        topic_id: topic.id
      }

      topic\refresh!
      assert.false topic\is_archived!

  describe "move", ->
    it "moves topic", ->
      old_cateory_id = topic.category_id
      other_category = factory.Categories {
        parent_category_id: topic.category_id
        user_id: current_user.id
      }

      method "move_topic", {
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

