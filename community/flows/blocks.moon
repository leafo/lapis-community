
import Flow from require "lapis.flow"

import Users from require "models"
import Blocks from require "community.models"

import assert_error from require "lapis.application"
import assert_valid from require "lapis.validate"

class BlocksFlow extends Flow
  expose_assigns: true

  new: (req) =>
    super req
    assert @current_user, "missing current user for blocks flow"

  load_blocked_user: =>
    assert_valid @params, {
      {"blocked_user_id", is_integer: true}
    }

    @blocked = assert_error Users\find(@params.blocked_user_id), "invalid user"
    assert_error @blocked.id != @current_user.id, "you can not block yourself"

  block_user: =>
    @load_blocked_user!
    Blocks\create {
      blocking_user_id: @current_user.id
      blocked_user_id: @blocked.id
    }

    true

  unblock_user: =>
    @load_blocked_user!
    block = Blocks\find {
      blocking_user_id: @current_user.id
      blocked_user_id: @blocked.id
    }

    block and block\delete!
