
import Flow from require "lapis.flow"

import Users from require "models"
import Blocks from require "community.models"

import assert_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import assert_page, require_login from require "community.helpers.app"

class BlocksFlow extends Flow
  expose_assigns: true

  new: (req) =>
    super req
    assert @current_user, "missing current user for blocks flow"

  show_blocks: =>
    assert_page @

    @pager = Blocks\paginated "
      where blocking_user_id = ?
      order by created_at desc
    ", @current_user.id, {
      per_page: 40
      prepare_results: (blocks) ->
        Blocks\preload_relations blocks, "blocked_user"
        blocks
    }

    @blocks = @pager\get_page @page
    @blocks

  load_blocked_user: =>
    return if @blocked

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
