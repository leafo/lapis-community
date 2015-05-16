import Flow from require "lapis.flow"

db = require "lapis.db"

import assert_valid from require "lapis.validate"
import assert_error from require "lapis.application"
import assert_page, require_login from require "community.helpers.app"
import trim_filter from require "lapis.util"
import filter_update from require "community.helpers.models"

import CategoryGroups from require "community.models"

limits = require "community.limits"

class CategoryGroupsFlow extends Flow
  expose_assigns: true

  load_category_group: =>
    return if @category_group

    assert_valid @params, {
      {"category_group_id", is_integer: true}
    }

    @category_group = CategoryGroups\find @params.category_group_id
    assert_error @category_group, "invalid group"

  validate_params: =>
    assert_valid @params, {
      {"category_group", type: "table"}
    }

    group_params = trim_filter @params.category_group, {
      "title"
      "description"
      "rules"
    }

    assert_valid group_params, {
      {"title", optional: true, max_length: limits.MAX_TITLE_LEN}
      {"description", optional: true, max_length: limits.MAX_BODY_LEN}
      {"rules", optional: true, max_length: limits.MAX_BODY_LEN}
    }

    group_params.title or= db.NULL
    group_params.description or= db.NULL
    group_params.rules or= db.NULL

    group_params

  new_category_group: require_login =>
    create_params = @validate_params!
    create_params.user_id = @current_user.id
    @category_group = CategoryGroups\create create_params
    true

  edit_category_group: require_login =>
    @load_category_group!
    assert_error @category_group\allowed_to_edit(@current_user),
      "invalid category group"

    update_params = @validate_params!
    update_params = filter_update @category_group, update_params
    @category_group\update update_params
    true

  moderators_flow: =>
    @load_category_group!
    ModeratorsFlow = require "community.flows.moderators"
    ModeratorsFlow @, @category_group

  show_categories: =>
    @load_category_group!
    assert_page @

    @pager = @category_group\get_categories_paginated!
    @categories = @pager\get_page @page
    @categories


