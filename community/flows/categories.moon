
import Flow from require "lapis.flow"

import Categories, Topics, Posts, Users from require "models"

import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"

class CategoriesFlow extends Flow
  new: (req) =>
    super req
    assert @current_user, "missing current user for post flow"

  _assert_category: =>
    assert_valid @params, {
      {"category_id", is_integer: true}
    }

    @category = Categories\find @params.category_id
    assert_error @category, "invalid category"

  show_members: =>
    @_assert_category!
    -- ...

  add_member: =>
    @_assert_category!
    assert_error @category\allowed_to_edit_members(@current_user), "invalid category"

    import CategoryMembers from require "models"

    assert_valid @params, {
      {"user_id", is_integer: true}
    }

    @user = assert_error Users\find @params.user_id, "invalid user"
    CategoryMembers\create category_id: @category.id, user_id: @user.id
    true

  remove_member: =>
    @_assert_category!
    assert_error @category\allowed_to_edit_members(@current_user), "invalid category"

    import CategoryMembers from require "models"

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

  accept_member: =>
    @_assert_category!
    import CategoryMembers from require "models"
    membership = CategoryMembers\find {
      category_id: @category.id
      user_id: @current_user.id
      accepted: false
    }
    assert_error membership, "invalid membership"
    membership\update accepted: true
    true

