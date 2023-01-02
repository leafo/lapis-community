import Flow from require "lapis.flow"

db = require "lapis.db"

import assert_valid from require "lapis.validate"
import assert_error from require "lapis.application"
import require_current_user from require "community.helpers.app"
import filter_update from require "community.helpers.models"

import CategoryGroups from require "community.models"

limits = require "community.limits"
shapes = require "community.helpers.shapes"

import types from require "tableshape"

class CategoryGroupsFlow extends Flow
  expose_assigns: true

  bans_flow: =>
    @load_category_group!
    BansFlow = require "community.flows.bans"
    BansFlow @, @category_group

  load_category_group: =>
    return if @category_group

    assert_valid @params, {
      {"category_group_id", is_integer: true}
    }

    @category_group = CategoryGroups\find @params.category_group_id
    assert_error @category_group, "invalid group"

  validate_params: =>
    shapes.assert_valid @params.category_group, {
      {"title", shapes.db_nullable shapes.limited_text limits.MAX_TITLE_LEN }
      {"description", shapes.db_nullable shapes.limited_text limits.MAX_BODY_LEN }
      {"rules", shapes.db_nullable shapes.limited_text limits.MAX_BODY_LEN }
    }

  new_category_group: require_current_user =>
    create_params = @validate_params!
    create_params.user_id = @current_user.id
    @category_group = CategoryGroups\create create_params
    true

  edit_category_group: require_current_user =>
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

    params = shapes.assert_valid @params, {
      {"page", shapes.page_number}
    }

    @pager = @category_group\get_categories_paginated!
    @categories = @pager\get_page params.page
    @categories


