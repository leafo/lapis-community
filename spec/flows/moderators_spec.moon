import use_test_env from require "lapis.spec"
import in_request from require "spec.flow_helpers"

factory = require "spec.factory"

describe "moderators flow", ->
  use_test_env!

  local current_user

  import Users from require "spec.models"

  import
    Categories
    Moderators
    from require "spec.community_models"

  before_each ->
    current_user = factory.Users!

  add_moderator = (post) ->
    in_request {
      :post
    }, =>
      @current_user = current_user
      @flow("moderators")\add_moderator!

  remove_moderator = (post) ->
    in_request {
      :post
    }, =>
      @current_user = current_user
      @flow("moderators")\remove_moderator!

  describe "add_moderator", ->
    it "should fail to do anything with missing params", ->
      assert.has_error(
        -> res = add_moderator!
        {
          message: {
            "object_id must be an integer"
            "object_type must be one of category, category_group"
          }
        }
      )

    it "should let category owner add moderator", ->
      category = factory.Categories user_id: current_user.id
      other_user = factory.Users!

      mod = assert add_moderator {
        object_type: "category"
        object_id: category.id
        user_id: other_user.id
      }

      mod = assert unpack Moderators\select!
      assert.same false, mod.accepted
      assert.same false, mod.admin

      assert.same other_user.id, mod.user_id
      assert.same category.id, mod.object_id
      assert.same Moderators.object_types.category, mod.object_type

    it "should not let category owner add self", ->
      category = factory.Categories user_id: current_user.id

      assert.has_error(
        ->
          add_moderator {
            object_type: "category"
            object_id: category.id
            user_id: current_user.id
          }

        {
          message: {
            "you can't chose yourself"
          }
        }
      )

    it "should not add owner", ->
      owner = factory.Users!
      category = factory.Categories user_id: owner.id

      factory.Moderators {
        object: category
        user_id: current_user.id
        admin: true
      }

      other_user = factory.Users!

      assert.has_error(
        ->
        add_moderator {
          object_type: "category"
          object_id: category.id
          user_id: owner.id
        }

        {
          message: { "already moderator" }
        }
      )

    it "doesn't add existing moderator", ->
      category = factory.Categories user_id: current_user.id
      mod = factory.Moderators { object: category }

      assert.has_error(
        ->
          add_moderator {
            object_type: "category"
            object_id: category.id
            user_id: mod.user_id
          }
        {
          message: { "already moderator" }
        }
      )

    it "should let category admin add moderator", ->
      category = factory.Categories!
      factory.Moderators {
        object: category
        user_id: current_user.id
        admin: true
      }

      other_user = factory.Users!
      mod = assert add_moderator {
        object_type: "category"
        object_id: category.id
        user_id: other_user.id
      }

      mod = assert unpack Moderators\select [[
        where user_id != ?
      ]], current_user.id

      assert.same false, mod.accepted
      assert.same false, mod.admin

      assert.same other_user.id, mod.user_id
      assert.same category.id, mod.object_id
      assert.same Moderators.object_types.category, mod.object_type

    it "should not let stranger add moderator", ->
      category = factory.Categories!
      other_user = factory.Users!

      assert.has_error(
        ->
          add_moderator {
            object_type: "category"
            object_id: category.id
            user_id: other_user.id
          }

        {
          message: {
            "invalid moderatable object"
          }
        }
      )

      assert.same {}, Moderators\select!

    it "should not let non-admin moderator add moderator", ->
      category = factory.Categories!
      factory.Moderators {
        object: category
        user_id: current_user.id
      }

      other_user = factory.Users!

      assert.has_error(
        ->
          add_moderator {
            object_type: "category"
            object_id: category.id
            user_id: other_user.id
          }

        {
          message: { "invalid moderatable object" }
        }
      )


  describe "remove_moderator", ->
    it "fails with missing object", ->
      assert.has_error(
        -> remove_moderator {}
        {
          message: {
            "object_id must be an integer",
            "object_type must be one of category, category_group"
          }
        }
      )

    it "doesn't let stranger remove moderator", ->
      category = factory.Categories!
      mod = factory.Moderators object: category

      assert.has_error(
        ->
          remove_moderator {
            object_type: "category"
            object_id: mod.object_id
            user_id: mod.user_id
          }

        {
          message: { "invalid moderatable object" }
        }
      )

    it "should let category owner remove moderator", ->
      category = factory.Categories user_id: current_user.id
      mod = factory.Moderators object: category

      assert remove_moderator {
        object_type: "category"
        object_id: mod.object_id
        user_id: mod.user_id
      }

      assert.same {}, Moderators\select!

    it "should let category admin remove moderator", ->
      category = factory.Categories!
      factory.Moderators {
        object: category
        user_id: current_user.id
        admin: true
      }

      mod = factory.Moderators object: category
      assert remove_moderator {
        object_type: "category"
        object_id: mod.object_id
        user_id: mod.user_id
      }

    it "should let (non admin/owner) moderator remove self", ->
      mod = factory.Moderators user_id: current_user.id

      remove_moderator {
        object_type: "category"
        object_id: mod.object_id
        user_id: mod.user_id
      }

      assert.same {}, Moderators\select!

    it "should not let non-admin moderator remove moderator", ->
      factory.Moderators user_id: current_user.id
      mod = factory.Moderators!

      assert.has_error(
        ->
          remove_moderator {
            object_type: "category"
            object_id: mod.object_id
            user_id: mod.user_id
          }
        {
          message: {"invalid moderatable object"}
        }
      )

  describe "accept_moderator_position", ->
    accept_moderator_position = (post) ->
      in_request {
        :post
      }, =>
        @current_user = current_user
        @flow("moderators")\accept_moderator_position!

    it "should do nothing for stranger", ->
      mod = factory.Moderators accepted: false

      assert.has_error(
        ->
          accept_moderator_position {
            object_type: "category"
            object_id: mod.object_id
          }
        {
          message: { "invalid moderator" }
        }
      )

      mod\refresh!
      assert.same false, mod.accepted

    it "should accept moderator position", ->
      mod = factory.Moderators accepted: false, user_id: current_user.id


      assert accept_moderator_position {
        object_type: "category"
        object_id: mod.object_id
      }

      mod\refresh!
      assert.same true, mod.accepted

    it "should reject moderator position", ->
      mod = factory.Moderators accepted: false, user_id: current_user.id

      assert remove_moderator {
        object_type: "category"
        object_id: mod.object_id

        user_id: mod.user_id
        current_user_id: current_user.id
      }

      assert.same {}, Moderators\select!


  describe "show moderators", ->
    show_moderators = (post) ->
      in_request {
        :post
      }, =>
        @current_user = current_user
        @flow("moderators")\show_moderators!

    it "should get moderators when there are none", ->
      category = factory.Categories!

      moderators = show_moderators {
        object_type: "category"
        object_id: category.id
      }

      assert.same {}, moderators

    it "should get moderators when there are some", ->
      category = factory.Categories!
      factory.Moderators! -- unrelated mod

      ms = for i=1,2
        factory.Moderators object: category

      moderators = show_moderators {
        object_type: "category"
        object_id: category.id
      }

      assert.same {
        {
          category.id
          ms[1].user_id
        }
        {
          category.id
          ms[2].user_id
        }
      }, [{m.object_id, m.user_id} for m in *moderators]

