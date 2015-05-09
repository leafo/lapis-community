
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

  _assert_blocked: =>
    assert_valid @params, {
      {"blocked_user_id", is_integer: true}
    }

    @blocked = assert_error Users\find(@params.blocked_user_id), "invalid user"
    assert_error @blocked.user_id != @current_user.id, "invalid user"

  block_user: =>
    @_assert_blocked!
    Blocks\create {
      blocking_user_id: @current_user.id
      blocked_user_id: @blocked.id
    }

    true

  unblock_user: =>
    @_assert_blocked!
    block = Blocks\find {
      blocking_user_id: @current_user.id
      blocked_user_id: @blocked.id
    }

    block and block\delete!
