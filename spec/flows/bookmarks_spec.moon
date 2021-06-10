import use_test_env from require "lapis.spec"
import in_request from require "spec.flow_helpers"

factory = require "spec.factory"

describe "flows.bookmarks", ->
  use_test_env!

  import Users from require "spec.models"
  import Bookmarks, Topics from require "spec.community_models"

  local current_user

  before_each ->
    current_user = factory.Users!

  describe "show", ->
    show_topic_bookmarks = (get) ->
      in_request {
        :get
      }, =>
        @current_user = current_user
        @flow("bookmarks")\show_topic_bookmarks!
        @topics

    it "fetches empty topic list", ->
      assert.same {}, show_topic_bookmarks!

    it "fetches topic with bookmark", ->
      other_topic = factory.Topics!
      Bookmarks\save other_topic, factory.Users!

      topics = for i=1,2
        with topic = factory.Topics!
          Bookmarks\save topic, current_user

      fetched = show_topic_bookmarks!
      assert.same {t.id, true for t in *topics},
         {t.id, true for t in *fetched}

  describe "save", ->
    save_bookmark = (post={}) ->
      in_request { :post }, =>
        @current_user = current_user
        @flow("bookmarks")\save_bookmark! or "noop"

    it "should save a bookmark", ->
      topic = factory.Topics!

      assert save_bookmark {
        object_type: "topic"
        object_id: topic.id
      }

      assert.same 1, Bookmarks\count!
      bookmark = unpack Bookmarks\select!
      assert.same Bookmarks.object_types.topic, bookmark.object_type
      assert.same topic.id, bookmark.object_id
      assert.same current_user.id, bookmark.user_id

    it "should not error if bookmark exists", ->
      topic = factory.Topics!
      for i=1,2
        save_bookmark {
          object_type: "topic"
          object_id: topic.id
        }

      assert.same 1, Bookmarks\count!

  describe "remove", ->
    remove_bookmark = (post={}) ->
      in_request { :post }, =>
        @current_user = current_user
        @flow("bookmarks")\remove_bookmark! or "noop"

    it "removes bookmark", ->
      bm = factory.Bookmarks user_id: current_user.id

      remove_bookmark {
        object_type: "topic"
        object_id: bm.object_id
      }

      assert.same 0, Bookmarks\count!

    it "handles removing non-existant bookmark", ->
      other_bm = factory.Bookmarks!

      remove_bookmark {
        object_type: "topic"
        object_id: other_bm.object_id
      }

      assert.same 1, Bookmarks\count!

