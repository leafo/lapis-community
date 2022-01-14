import in_request from require "spec.flow_helpers"

factory = require "spec.factory"

describe "blocks", ->
  import Users from require "spec.models"
  import Blocks from require "spec.community_models"

  local current_user

  before_each =>
    current_user = factory.Users!

  block_user = (post) ->
    in_request {
      :post
    }, =>
      @current_user = current_user
      @flow("blocks")\block_user!

  unblock_user = (post) ->
    in_request {
      :post
    }, =>
      @current_user = current_user
      @flow("blocks")\unblock_user! or "noop"

  it "does nothing with incorrect params", ->
    assert.has_error(
      -> block_user { }
      {
        message: {
          "blocked_user_id must be an integer"
        }
      }
    )

  it "should block user", ->
    other_user = factory.Users!

    assert block_user {
      blocked_user_id: other_user.id
    }

    blocks = Blocks\select!
    assert.same 1, #blocks
    block = unpack blocks
    assert.same current_user.id, block.blocking_user_id
    assert.same other_user.id, block.blocked_user_id

  it "should not error on double block", ->
    other_user = factory.Users!
    factory.Blocks blocking_user_id: current_user.id, blocked_user_id: other_user.id

    assert block_user {
      blocked_user_id: other_user.id
    }

  it "should unblock user", ->
    other_user = factory.Users!
    factory.Blocks {
      blocking_user_id: current_user.id
      blocked_user_id: other_user.id
    }

    factory.Blocks!

    assert unblock_user {
      blocked_user_id: other_user.id
    }

    assert.same 1, Blocks\count!
    assert.same {}, Blocks\select "where blocking_user_id = ?", current_user.id

  it "doesn't error when trying to unblock someone who isn't blocked", ->
    other_user = factory.Users!

    -- block on user from different account
    factory.Blocks blocked_user_id: other_user.id

    unblock_user {
      blocked_user_id: other_user.id
    }

    assert.same 1, Blocks\count!

  describe "show blocks", ->
    show_blocks = (get) ->
      in_request {
        :get
      }, =>
        @current_user = current_user
        @flow("blocks")\show_blocks!

    it "show sempty blocks", ->
      factory.Blocks! -- unrelated block
      assert.same {}, show_blocks!

    it "shows blocks when there are some", ->
      factory.Blocks! -- unrelated block
      for i=1,2
        factory.Blocks blocking_user_id: current_user.id

      blocks = show_blocks!
      assert.same 2, #blocks

