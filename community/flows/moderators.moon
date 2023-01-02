
import Flow from require "lapis.flow"

db = require "lapis.db"

import assert_valid from require "lapis.validate"
import assert_error from require "lapis.application"
import assert_page, require_current_user from require "community.helpers.app"

shapes = require "community.helpers.shapes"

import Users from require "models"

import Moderators from require "community.models"

import preload from require "lapis.db.model"

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

    @user = if @params.user_id
      user_id = assert_error shapes.db_id\describe("user_id")\transform @params.user_id
      Users\find user_id
    elseif @params.username
      username = assert_error shapes.limited_text(255)\describe("username")\transform @params.username
      Users\find { :username }

    assert_error @user, "invalid user"

    unless allow_self
      assert_error not @current_user or @current_user.id != @user.id,
        "you can't chose yourself"

    @moderator = Moderators\find_for_object_user @object, @user

  add_moderator: require_current_user =>
    @load_user!

    assert_error @object\allowed_to_edit_moderators(@current_user),
      "invalid moderatable object"

    assert_error not @object\allowed_to_moderate(@user, true),
      "already moderator"

    Moderators\create {
      user_id: @user.id
      object: @object
    }

  remove_moderator: require_current_user =>
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
      order by created_at desc, user_id asc
    ", Moderators\object_type_for_object(@object), @object.id, {
      per_page: 20
      prepare_results: (moderators) ->
        preload moderators, "user"
        moderators
    }

    @moderators = @pager\get_page @page
    @moderators

  get_pending_moderator: =>
    unless @pending_moderator
      @load_object!
      mod = Moderators\find_for_object_user @object, @current_user
      @pending_moderator = mod and not mod.accepted and mod

    @pending_moderator

  accept_moderator_position: require_current_user =>
    mod = assert_error @get_pending_moderator!, "invalid moderator"
    mod\update accepted: true
    true


