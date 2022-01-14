import in_request from require "spec.flow_helpers"

factory = require "spec.factory"

import types from require "tableshape"

describe "flows.bookmarks", ->
  import Users from require "spec.models"
  import Subscriptions, Categories, Topics from require "spec.community_models"

  describe "subscribe_to_topic", ->
    local topic

    before_each ->
      topic = factory.Topics!

    it "subscribes", ->
      user = factory.Users!

      in_request {}, =>
        @current_user = user
        @flow("subscriptions")\subscribe_to_topic topic

      assert types.shape({
        types.shape {
          object_id: topic.id
          object_type: Subscriptions.object_types.topic
          user_id: user.id
          subscribed: true
        }, open: true

      }), Subscriptions\select!

    it "doesn't subscribe to topic that isn't visible", ->
      topic\update deleted: true

      user = factory.Users!

      assert.has_error(
        ->
          in_request {}, =>
            @current_user = user
            @flow("subscriptions")\subscribe_to_topic topic

        {message: { "invalid topic" } }
      )

      assert.same {}, Subscriptions\select!

  describe "subscribe_to_category", ->
    local category

    before_each ->
      category = factory.Categories!

    it "subscribes", ->
      user = factory.Users!

      assert in_request {}, =>
        @current_user = user
        @flow("subscriptions")\subscribe_to_category category
        true

      assert types.shape({
        types.shape {
          object_id: category.id
          object_type: Subscriptions.object_types.category
          user_id: user.id
          subscribed: true
        }, open: true

      }), Subscriptions\select!


    it "doesn't subscribe to category that isn't visible", ->
      category\update hidden: true

      user = factory.Users!

      assert.has_error(
        ->
          in_request {}, =>
            @current_user = user
            @flow("subscriptions")\subscribe_to_category category

        { message: { "invalid category" } }
      )

      assert.same {}, Subscriptions\select!



  describe "show_subscriptions", ->
    it "gets empty subscriptions", ->

      user = factory.Users!

      subs = assert in_request {}, =>
        @current_user = user
        @flow("subscriptions")\show_subscriptions!
        @subscriptions

      assert.same {}, subs

    it "gets some subscriptions", ->
      user = factory.Users!

      cat_sub = Subscriptions\create {
        user_id: user.id
        object_type: Subscriptions.object_types.category
        object_id: factory.Categories!.id
      }

      -- hidden
      Subscriptions\create {
        user_id: user.id
        object_type: Subscriptions.object_types.category
        object_id: factory.Categories!.id
        subscribed: false
      }

      topic_sub = Subscriptions\create {
        user_id: user.id
        object_type: Subscriptions.object_types.topic
        object_id: factory.Topics!.id
      }

      -- unrelated subscription
      Subscriptions\create {
        user_id: factory.Users!.id
        object_type: Subscriptions.object_types.topic
        object_id: factory.Topics!.id
      }

      subs = assert in_request {}, =>
        @current_user = user
        @flow("subscriptions")\show_subscriptions!
        @subscriptions

      subs = {Subscriptions.object_types\to_name(sub.object_type), sub.object_id for sub in *subs}

      assert.same {
        category: cat_sub.object_id
        topic: topic_sub.object_id
      }, subs

