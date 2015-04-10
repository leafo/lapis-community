
import Flow from require "lapis.flow"

db = require "lapis.db"

import assert_valid from require "lapis.validate"
import assert_error from require "lapis.application"
import assert_page from require "community.helpers.app"

import
  Users
  Categories
  CategoryModerators
  from require "models"

class ModeratorsFlow extends Flow
  expose_assigns: true

  new: (req, @category_flow) =>
    super req
    assert @category, "missing category"
    assert @current_user, "missing current user for post flow"

  load_user: (allow_self) =>
    @user = assert_error Users\find(@params.user_id), "invalid user"
    @moderator = @category\find_moderator @user

    if @moderator
      return if allow_self and @moderator.user_id == @current_user.id

    assert_error @category\allowed_to_edit_moderators(@current_user), "invalid category"

  add_moderator: =>
    @load_user!
    assert_error not @moderator, "already moderator"

    CategoryModerators\create {
      user_id: @user.id
      category_id: @category.id
    }

  remove_moderator: =>
    @load_user true
    assert_error @moderator, "not a moderator"
    @moderator\delete!

  show_moderators: =>
    assert_page @

    @pager = @category\get_moderators per_page: 20
    @moderators = @pager\get_page @page
    @moderators

  accept_moderator_position: =>
    assert_valid @params, {
      {"category_id", is_integer: true }
    }

    mod = CategoryModerators\find {
      user_id: @current_user.id
      category_id: @params.category_id
    }

    assert_error mod and not mod.accepted, "invalid moderator"
    mod\update accepted: true
    true


