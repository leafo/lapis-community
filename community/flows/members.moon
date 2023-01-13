
import Flow from require "lapis.flow"

db = require "lapis.db"
import with_params from require "lapis.validate"
import assert_error from require "lapis.application"
import assert_page, require_current_user from require "community.helpers.app"

import Users from require "models"
import CategoryMembers from require "community.models"

import preload from require "lapis.db.model"

types = require "lapis.validate.types"

class MembersFlow extends Flow
  expose_assigns: true

  new: (req) =>
    super req
    assert @category, "can't create a members flow without a category on the request object"

  load_user: with_params {
    {"user_id", types.empty + types.db_id}
    {"username", types.empty + types.limited_text 256}
  }, (params) =>
    user = if params.user_id
      Users\find params.user_id
    elseif params.username
      Users\find username: params.username

    assert_error user, "invalid user"
    assert_error @current_user.id != user.id, "can't add self"

    @user = user
    @member = @category\find_member @user

  show_members: =>
    assert_page @

    @pager = CategoryMembers\paginated [[
      where category_id = ?
      order by created_at desc, user_id desc
    ]], @category.id, per_page: 20, prepare_results: (members) ->
      preload members, "user"
      members

    @members = @pager\get_page @page
    @members

  add_member: require_current_user =>
    assert_error @category\allowed_to_edit_members(@current_user), "invalid category"
    @load_user!
    assert_error not @member, "already a member"
    CategoryMembers\create category_id: @category.id, user_id: @user.id
    true

  remove_member: require_current_user =>
    assert_error @category\allowed_to_edit_members(@current_user), "invalid category"
    @load_user!
    assert_error @member, "user is not member"
    @member\delete!
    true

  accept_member: require_current_user =>
    member = CategoryMembers\find {
      category_id: @category.id
      user_id: @current_user.id
      accepted: false
    }
    assert_error member, "no pending membership"
    member\update accepted: true
    true
