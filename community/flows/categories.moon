import Flow from require "lapis.flow"

import Users from require "models"
import Categories, CategoryMembers, ActivityLogs from require "community.models"

import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import trim_filter, slugify from require "lapis.util"

import assert_page, require_login from require "community.helpers.app"
import filter_update from require "community.helpers.models"

limits = require "community.limits"

db = require "lapis.db"

VALIDATIONS = {
  {"title", exists: true, max_length: limits.MAX_TITLE_LEN}

  {"short_description", optional: true, max_length: limits.MAX_TITLE_LEN}
  {"description", optional: true, max_length: limits.MAX_BODY_LEN}

  {"membership_type", one_of: Categories.membership_types}
  {"voting_type", one_of: Categories.voting_types}
}


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

  bans_flow: =>
    @load_category!
    BansFlow = require "community.flows.bans"
    BansFlow @, @category

  load_category: =>
    return if @category

    assert_valid @params, {
      {"category_id", is_integer: true}
    }

    @category = Categories\find @params.category_id
    assert_error @category, "invalid category"
    assert_error @category\allowed_to_view(@current_user), "invalid category"

  reports: =>
    @load_category!
    ReportsFlow = require "community.flows.reports"
    ReportsFlow(@)\show_reports @category

  moderation_logs: =>
    @load_category!
    assert_error @category\allowed_to_moderate(@current_user), "invalid category"

    assert_page @
    import ModerationLogs from require "community.models"
    @pager = ModerationLogs\paginated "
      where category_id = ? order by id desc
    ", @category.id, prepare_results: (logs) ->
      ModerationLogs\preload_objects logs
      Users\include_in logs, "user_id"
      logs

    @moderation_logs = @pager\get_page @page

  pending_posts: =>
    @load_category!
    assert_error @category\allowed_to_moderate(@current_user), "invalid category"

    import PendingPosts, Topics, Posts from require "community.models"

    assert_valid @params, {
      {"status", optional: true, one_of: PendingPosts.statuses}
    }

    assert_page @

    status = PendingPosts.statuses\for_db @params.status or "pending"
    @pager = PendingPosts\paginated "
      where category_id = ? and status = ?
      order by id asc
    ", @category.id, status, {
      prepare_results: (pending) ->
        Categories\include_in pending, "category_id"
        Users\include_in pending, "user_id"
        Topics\include_in pending, "topic_id"
        Posts\include_in pending, "parent_post_id"
        pending
    }

    @pending_posts = @pager\get_page @page
    @pending_posts

  edit_pending_post: =>
    import PendingPosts from require "community.models"

    @load_category!
    assert_valid @params, {
      {"pending_post_id", is_integer: true}
      {"action", one_of: {
        "promote"
        "deleted"
        "spam"
      }}
    }

    @pending_post = PendingPosts\find @params.pending_post_id
    assert_error @pending_post, "invalid pending post"
    category_id = @pending_post.category_id or @pending_post\get_topic!.category_id
    assert_error category_id == @category.id, "invalid pending post for category"
    assert_error @pending_post\allowed_to_moderate(@current_user), "invalid pending post"

    @post = switch @params.action
      when "promote"
        @pending_post\promote!
      when "deleted", "spam"
        @pending_post\update {
          status: PendingPosts.statuses\for_db @params.action
        }

    true, @post


  validate_params: =>
    @params.category or= {}
    assert_valid @params, {
      {"category", type: "table"}
    }

    has_field = {k, true for k in pairs @params.category}

    category_params = trim_filter @params.category, {
      "title"
      "membership_type"
      "voting_type"
      "description"
      "short_description"
      "archived"
      "hidden"
      "rules"
    }

    assert_valid category_params, [v for v in *VALIDATIONS when has_field[v]]

    if has_field.archived or has_field.update_archived
      category_params.archived = not not category_params.archived

    if has_field.hidden or has_field.update_hidden
      category_params.hidden = not not category_params.hidden

    if has_field.membership_type
      category_params.membership_type = Categories.membership_types\for_db category_params.membership_type

    if has_field.voting_type
      category_params.voting_type = Categories.voting_types\for_db category_params.voting_type

    if has_field.title
      category_params.slug = slugify category_params.title

    if has_field.description
      category_params.description or= db.NULL

    if has_field.short_description
      category_params.short_description or= db.NULL

    if has_field.rules
      category_params.rules or= db.NULL

    category_params

  new_category: require_login =>
    create_params = @validate_params!
    create_params.user_id = @current_user.id
    @category = Categories\create create_params

    ActivityLogs\create {
      user_id: @current_user.id
      object: @category
      action: "create"
    }

    true

  edit_category: require_login =>
    @load_category!
    assert_error @category\allowed_to_edit(@current_user), "invalid category"

    update_params = @validate_params!
    update_params = filter_update @category, update_params

    @category\update update_params

    if next update_params
      ActivityLogs\create {
        user_id: @current_user.id
        object: @category
        action: "edit"
      }

    true

