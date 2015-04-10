
import Flow from require "lapis.flow"

db = require "lapis.db"

import assert_valid from require "lapis.validate"
import assert_error from require "lapis.application"
import assert_page, require_login from require "community.helpers.app"

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

  load_user: (allow_self) =>
    assert_valid @params, {
      {"user_id", optional: true, is_integer: true}
      {"username", optional: true}
    }

    @user = if @params.user_id
      Users\find @params.user_id
    elseif @params.username
      Users\find username: @params.username

    assert_error @user, "invalid user"

    unless allow_self
      assert_error not @current_user or @current_user.id != @user.id, "you can't chose yourself"

    @moderator = @category\find_moderator @user

  add_moderator: require_login =>
    @load_user!
    assert_error @category\allowed_to_edit_moderators(@current_user), "invalid category"
    assert_error not @moderator, "already moderator"

    CategoryModerators\create {
      user_id: @user.id
      category_id: @category.id
    }

  remove_moderator: require_login =>
    @load_user true

    -- you can remove yourself
    unless @moderator and @moderator.user_id == @current_user.id
      assert_error @category\allowed_to_edit_moderators(@current_user), "invalid category"

    assert_error @moderator, "not a moderator"

    @moderator\delete!

  show_moderators: =>
    assert_page @

    @pager = CategoryModerators\paginated "
      where category_id = ?
      order by created_at desc
    ", @category.id, per_page: 20, prepare_results: (moderators) ->
      Users\include_in moderators, "user_id"
      moderators

    @moderators = @pager\get_page @page
    @moderators

  accept_moderator_position: require_login =>
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


