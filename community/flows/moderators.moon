
import Flow from require "lapis.flow"

db = require "lapis.db"

import assert_valid from require "lapis.validate"
import assert_error from require "lapis.application"

import
  Users
  Categories
  CategoryModerators
  from require "models"

class Moderators extends Flow
  new: (req) =>
    super req
    assert @current_user, "missing current user for post flow"

  _assert_category: (allow_self) =>
    assert_valid @params, {
      {"category_id", is_integer: true }
      {"user_id", is_integer: true}
    }

    @category = assert_error Categories\find(@params.category_id), "invalid category"

    @user = assert_error Users\find(@params.user_id), "invalid user"
    @moderator = @category\find_moderator @user

    if @moderator
      return if allow_self and @moderator.user_id == @current_user.id

    assert_error @category\allowed_to_edit_moderators(@current_user), "invalid category"

  add_moderator: =>
    @_assert_category!
    assert_error not @moderator, "already moderator"

    CategoryModerators\create {
      user_id: @user.id
      category_id: @category.id
    }

  remove_moderator: =>
    @_assert_category true
    assert_error @moderator, "not a moderator"
    @moderator\delete!

  accept_moderator_position: =>
    assert_valid @params, {
      {"category_id", is_integer: true }
    }

    mod = CategoryModerators\select [[
      where user_id = ? and category_id = ?
    ]], @current_user.id, @params.category_id

    assert_error mod and not mod.accepted, "invalid moderator"
    true


