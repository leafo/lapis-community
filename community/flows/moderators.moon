
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

  new: (req) =>
    super req
    assert @current_user, "missing current user for post flow"

  _assert_category: =>
    assert_valid @params, {
      {"category_id", is_integer: true}
    }

    @category = Categories\find @params.category_id
    assert_error @category, "invalid category"

  _assert_category_and_user: (allow_self) =>
    @_assert_category!

    @user = assert_error Users\find(@params.user_id), "invalid user"
    @moderator = @category\find_moderator @user

    if @moderator
      return if allow_self and @moderator.user_id == @current_user.id

    assert_error @category\allowed_to_edit_moderators(@current_user), "invalid category"

  add_moderator: =>
    @_assert_category_and_user!
    assert_error not @moderator, "already moderator"

    CategoryModerators\create {
      user_id: @user.id
      category_id: @category.id
    }

  remove_moderator: =>
    @_assert_category_and_user true
    assert_error @moderator, "not a moderator"
    @moderator\delete!

  show_moderators: =>
    @_assert_category!
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


