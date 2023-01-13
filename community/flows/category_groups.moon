import Flow from require "lapis.flow"

db = require "lapis.db"

import assert_valid, with_params from require "lapis.validate"
import assert_error from require "lapis.application"
import require_current_user, assert_page from require "community.helpers.app"
import filter_update from require "community.helpers.models"

import CategoryGroups from require "community.models"

limits = require "community.limits"
shapes = require "community.helpers.shapes"
types = require "lapis.validate.types"

class CategoryGroupsFlow extends Flow
  expose_assigns: true

  bans_flow: =>
    @load_category_group!
    BansFlow = require "community.flows.bans"
    BansFlow @, @category_group

  load_category_group: =>
    return if @category_group

    assert_valid @params, types.params_shape {
      {"category_group_id", types.db_id}
    }

    @category_group = CategoryGroups\find @params.category_group_id
    assert_error @category_group, "invalid group"

  validate_params: with_params {
    {"category_group", types.params_shape {
      {"title", shapes.db_nullable types.limited_text limits.MAX_TITLE_LEN }
      {"description", shapes.db_nullable types.limited_text limits.MAX_BODY_LEN }
      {"rules", shapes.db_nullable types.limited_text limits.MAX_BODY_LEN }
    }}
  }, (params) => params.category_group

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
    assert_page @

    @pager = @category_group\get_categories_paginated!
    @categories = @pager\get_page @page
    @categories


