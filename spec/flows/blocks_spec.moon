import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Blocks from require "community.models"

import TestApp from require "spec.helpers"
import capture_errors_json from require "lapis.application"

factory = require "spec.factory"

class BlocksApp extends TestApp
  @require_user!

  @before_filter =>
    BlocksFlow = require "community.flows.blocks"
    @flow = BlocksFlow @

  "/block-user": capture_errors_json =>
    @flow\block_user!
    json: {success: true}

  "/unblock-user": capture_errors_json =>
    @flow\unblock_user!
    json: {success: true}

  "/show-blocks": capture_errors_json =>
    blocks = @flow\show_blocks!
    json: { success: true, :blocks }

describe "blocks", ->
  use_test_env!

  local current_user

  before_each =>
    truncate_tables Users, Blocks
    current_user = factory.Users!

  it "should block user", ->
    other_user = factory.Users!
    res = BlocksApp\get current_user, "/block-user", {
      blocked_user_id: other_user.id
    }

    assert.truthy res.success
    blocks = Blocks\select!
    assert.same 1, #blocks
    block = unpack blocks
    assert.same current_user.id, block.blocking_user_id
    assert.same other_user.id, block.blocked_user_id

  it "should not error on double block", ->
    other_user = factory.Users!
    factory.Blocks blocking_user_id: current_user.id, blocked_user_id: other_user.id

    BlocksApp\get current_user, "/block-user", {
      blocked_user_id: other_user.id
    }

  it "should unblock user", ->
    other_user = factory.Users!
    factory.Blocks blocking_user_id: current_user.id, blocked_user_id: other_user.id

    res = BlocksApp\get current_user, "/unblock-user", {
      blocked_user_id: other_user.id
    }

    assert.truthy res.success
    blocks = Blocks\select!
    assert.same 0, #blocks

  it "should not error on invalid unblock", ->
    other_user = factory.Users!

    res = BlocksApp\get current_user, "/unblock-user", {
      blocked_user_id: other_user.id
    }

  describe "show blocks", ->
    it "should get blocks when there are none", ->
      res = BlocksApp\get current_user, "/show-blocks"
      assert.same {success: true, blocks: {}}, res

    it "should get blocks when there are some", ->
      for i=1,2
        factory.Blocks blocking_user_id: current_user.id

      res = BlocksApp\get current_user, "/show-blocks"
      assert.same 2, #res.blocks

