
import Flow from require "lapis.flow"

db = require "lapis.db"
import assert_valid from require "lapis.validate"
import assert_error from require "lapis.application"
import assert_page, require_login from require "community.helpers.app"

import Users from require "models"
import CategoryMembers from require "community.models"

class MembersFlow extends Flow
  expose_assigns: true

  new: (req, @category_flow) =>
    super req
    assert @category, "missing category"

  load_user: =>
    assert_valid @params, {
      {"user_id", optional: true, is_integer: true}
      {"username", optional: true}
    }

    @user = if @params.user_id
      Users\find @params.user_id
    elseif @params.username
      Users\find username: @params.username

    assert_error @user, "invalid user"
    assert_error @current_user.id != @user.id, "can't add self"
    @member = @category\find_member @user

  show_members: =>
    assert_page @

    @pager = CategoryMembers\paginated [[
      where category_id = ?
      order by created_at desc
    ]], @category.id, per_page: 20, prepare_results: (members) ->
      CategoryMembers\preload_relations members, "user"
      members

    @members = @pager\get_page @page
    @members

  add_member: require_login =>
    assert_error @category\allowed_to_edit_members(@current_user), "invalid category"
    @load_user!
    assert_error not @member, "already a member"
    CategoryMembers\create category_id: @category.id, user_id: @user.id
    true

  remove_member: require_login =>
    assert_error @category\allowed_to_edit_members(@current_user), "invalid category"
    @load_user!
    assert_error @member, "user is not member"
    @member\delete!
    true

  accept_member: require_login =>
    member = CategoryMembers\find {
      category_id: @category.id
      user_id: @current_user.id
      accepted: false
    }
    assert_error member, "no pending membership"
    member\update accepted: true
    true
