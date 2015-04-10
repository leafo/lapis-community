import Flow from require "lapis.flow"

import Categories, Users, CategoryMembers from require "models"

import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import trim_filter from require "lapis.util"

import assert_page, require_login from require "community.helpers.app"
import filter_update from require "community.helpers.models"

limits = require "community.limits"

class CategoriesFlow extends Flow
  expose_assigns: true

  new: (req) =>
    super req

  moderators_flow: =>
    @load_category!
    ModeratorsFlow = require "community.flows.moderators"
    ModeratorsFlow @, @

  load_category: =>
    return if @category

    assert_valid @params, {
      {"category_id", is_integer: true}
    }

    @category = Categories\find @params.category_id
    assert_error @category, "invalid category"

  show_members: =>
    @load_category!
    assert_page @

    @pager = CategoryMembers\paginated [[
      where category_id = ?
      order by created_at desc
    ]], prepare_results: (members) =>
      Users\include_in members, "user_id"
      members

    @members = @pager\get_page @page
    @members

  add_member: require_login =>
    @load_category!
    assert_error @category\allowed_to_edit_members(@current_user), "invalid category"

    assert_valid @params, {
      {"user_id", is_integer: true}
    }

    @user = assert_error Users\find @params.user_id, "invalid user"
    CategoryMembers\create category_id: @category.id, user_id: @user.id
    true

  remove_member: require_login =>
    @load_category!
    assert_error @category\allowed_to_edit_members(@current_user), "invalid category"

    assert_valid @params, {
      {"user_id", is_integer: true}
    }

    membership = CategoryMembers\find {
      user_id: @params.user_id
      category_id: @category.id
    }

    assert_error membership, "invalid membership"
    membership\delete!
    true

  accept_member: require_login =>
    @load_category!

    membership = CategoryMembers\find {
      category_id: @category.id
      user_id: @current_user.id
      accepted: false
    }
    assert_error membership, "invalid membership"
    membership\update accepted: true
    true

  new_category: require_login =>
    assert_valid @params, {
      {"category", type: "table"}
    }

    new_category = @params.category
    trim_filter new_category

    assert_valid new_category, {
      {"name", exists: true, max_length: limits.MAX_TITLE_LEN}
      {"membership_type", one_of: Categories.membership_types}
    }

    @category = Categories\create {
      user_id: @current_user.id
      name: new_category.name
      membership_type: new_category.membership_type
    }

    true

  edit_category: require_login =>
    @load_category!
    assert_error @category\allowed_to_edit(@current_user), "invalid category"

    assert_valid @params, {
      {"category", exists: true, type: "table"}
    }

    category_update = trim_filter @params.category, {"name", "membership_type"}

    assert_valid category_update, {
      {"name", exists: true, max_length: limits.MAX_TITLE_LEN}
      {"membership_type", one_of: Categories.membership_types}
    }

    category_update.membership_type = Categories.membership_types\for_db category_update.membership_type
    category_update = filter_update @category, category_update

    if next category_update
      @category\update category_update

    true

