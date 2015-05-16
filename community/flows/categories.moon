import Flow from require "lapis.flow"

import Users from require "models"
import Categories, CategoryMembers from require "community.models"

import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import trim_filter, slugify from require "lapis.util"

import assert_page, require_login from require "community.helpers.app"
import filter_update from require "community.helpers.models"

limits = require "community.limits"

db = require "lapis.db"

class CategoriesFlow extends Flow
  expose_assigns: true

  moderators_flow: =>
    @load_category!
    ModeratorsFlow = require "community.flows.moderators"
    ModeratorsFlow @, @category

  members_flow: =>
    @load_category!
    MembersFlow = require "community.flows.members"
    MembersFlow @, @

  load_category: =>
    return if @category

    assert_valid @params, {
      {"category_id", is_integer: true}
    }

    @category = Categories\find @params.category_id
    assert_error @category, "invalid category"

  new_category: require_login =>
    assert_valid @params, {
      {"category", type: "table"}
    }

    new_category = @params.category
    trim_filter new_category

    assert_valid new_category, {
      {"title", exists: true, max_length: limits.MAX_TITLE_LEN}
      {"short_description", optional: true, max_length: limits.MAX_TITLE_LEN}
      {"description", optional: true, max_length: limits.MAX_BODY_LEN}

      {"membership_type", one_of: Categories.membership_types}
      {"voting_type", one_of: Categories.voting_types}
    }

    @category = Categories\create {
      user_id: @current_user.id
      title: new_category.title

      short_description: new_category.short_description
      description: new_category.description

      membership_type: new_category.membership_type
      voting_type: new_category.voting_type

      archived: not not new_category.archived
      hidden: not not new_category.hidden
    }

    true

  edit_category: require_login =>
    @load_category!
    assert_error @category\allowed_to_edit(@current_user), "invalid category"

    assert_valid @params, {
      {"category", exists: true, type: "table"}
    }

    category_update = trim_filter @params.category, {
      "title"
      "membership_type"
      "voting_type"
      "description"
      "short_description"
      "archived"
      "hidden"
    }

    assert_valid category_update, {
      {"title", exists: true, max_length: limits.MAX_TITLE_LEN}

      {"short_description", optional: true, max_length: limits.MAX_TITLE_LEN}
      {"description", optional: true, max_length: limits.MAX_BODY_LEN}

      {"membership_type", one_of: Categories.membership_types}
      {"voting_type", one_of: Categories.voting_types}
    }

    category_update.archived = not not category_update.archived
    category_update.hidden = not not category_update.hidden

    category_update.membership_type = Categories.membership_types\for_db category_update.membership_type
    category_update.voting_type = Categories.voting_types\for_db category_update.voting_type
    category_update.slug = slugify category_update.title

    category_update.description or= db.NULL
    category_update.short_description or= db.NULL

    category_update = filter_update @category, category_update

    if next category_update
      @category\update category_update

    true

