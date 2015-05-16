
import Flow from require "lapis.flow"

db = require "lapis.db"

import assert_valid from require "lapis.validate"
import assert_error from require "lapis.application"
import assert_page, require_login from require "community.helpers.app"

import Users from require "models"

import Moderators from require "community.models"

class ModeratorsFlow extends Flow
  expose_assigns: true

  new: (req, @object) =>
    super req

  load_object: =>
    return if @object

    assert_valid @params, {
      {"object_id", is_integer: true }
      {"object_type", one_of: Moderators.object_types}
    }

    model = Moderators\model_for_object_type @params.object_type
    @object = model\find @params.object_id

    assert_error @object, "invalid moderator object"

  load_user: (allow_self) =>
    @load_object!

    return if @user

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
      assert_error not @current_user or @current_user.id != @user.id,
        "you can't chose yourself"

    @moderator = Moderators\find_for_object_user @object, @user

  add_moderator: require_login =>
    @load_user!

    assert_error @object\allowed_to_edit_moderators(@current_user),
      "invalid moderatable object"

    assert_error not @moderator, "already moderator"

    Moderators\create {
      user_id: @user.id
      object: @object
    }

  remove_moderator: require_login =>
    @load_user true

    -- you can remove yourself
    unless @moderator and @moderator.user_id == @current_user.id
      assert_error @object\allowed_to_edit_moderators(@current_user),
        "invalid moderatable object"

    assert_error @moderator, "not a moderator"

    @moderator\delete!

  show_moderators: =>
    @load_object!
    assert_page @

    @pager = Moderators\paginated "
      where object_type = ? and object_id = ?
      order by created_at desc
    ", Moderators\object_type_for_object(@object), @object.id, {
      per_page: 20
      prepare_results: (moderators) ->
        Users\include_in moderators, "user_id"
        moderators
    }

    @moderators = @pager\get_page @page
    @moderators

  accept_moderator_position: require_login =>
    @load_object!

    mod = Moderators\find_for_object_user @object, @current_user

    assert_error mod and not mod.accepted, "invalid moderator"
    mod\update accepted: true

    true


