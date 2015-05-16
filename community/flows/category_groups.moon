import Flow from require "lapis.flow"

import assert_valid from require "lapis.validate"
import assert_error from require "lapis.application"
import assert_page, require_login from require "community.helpers.app"

import CategoryGroups from require "community.models"

class CategoryGroupsFlow extends Flow
  expose_assigns: true

  load_category_group: =>
    return if @category_group

    assert_valid @params, {
      {"category_group_id", is_integer: true}
    }

    @category_group = CategoryGroups\find @params.category_group_id
    assert_error @category_group, "invalid group"

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


