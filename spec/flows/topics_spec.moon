
import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Categories, Topics, Posts, TopicTags from require "community.models"

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

describe "topic tags", ->
  use_test_env!

  local current_user, topic

  before_each ->
    truncate_tables Users, Categories, Topics, Posts, TopicTags
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

