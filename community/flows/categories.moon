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

    children = @category\get_flat_children!
    category_ids = [c.id for c in *children]
    table.insert category_ids, @category.id

    assert_page @
    import ModerationLogs from require "community.models"
    @pager = ModerationLogs\paginated "
      where category_id in ? order by id desc
    ", db.list(category_ids), prepare_results: (logs) ->
      ModerationLogs\preload_relations logs, "object", "user"
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
        PendingPosts\preload_relations pending, "category", "user", "topic", "parent_post"
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
      "topic_posting_type"
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

    if has_field.topic_posting_type
      category_params.topic_posting_type = Categories.topic_posting_types\for_db category_params.topic_posting_type

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

  -- categories[1][title] = "hello!"
  -- categories[1][children][1][title] = "a child!"
  -- categories[2][title] = "reused category"
  -- categories[2][id] = "1234"
  set_children: require_login =>
    @load_category!
    assert_error @category\allowed_to_edit(@current_user), "invalid category"

    import convert_arrays from require "community.helpers.app"
    @params.categories or= {}

    assert_valid @params, {
      {"categories", type: "table"}
    }

    convert_arrays @params

    validate_category_params = (params) ->
      -- TODO: synchronize with the other validate
      assert_valid params, {
        {"id", optional: true, is_integer: true}
        {"title", exists: true, max_length: limits.MAX_TITLE_LEN}
        {"short_description", optional: true, max_length: limits.MAX_TITLE_LEN}
        {"hidden", optional: true, type: "string"}
        {"archived", optional: true, type: "string"}
        {"directory", optional: true, type: "string"}
        {"children", optional: true, type: "table"}
      }

      if params.children
        for child in *params.children
          validate_category_params child

    for category in *@params.categories
      validate_category_params category

    existing = @category\get_flat_children!
    existing_by_id = {c.id, c for c in *existing}
    existing_assigned = {}

    set_children = (parent, children) ->
      filtered = for c in *children
        if c.id
          c.category = existing_by_id[tonumber c.id]
          continue unless c.category
        c

      -- current depth, update or create
      for position, c in ipairs filtered
        update_params = {
          :position
          parent_category_id: parent.id
          title: c.title
          short_description: c.short_description or db.NULL
          hidden: not not c.hidden
          archived: not not c.archived
          directory: not not c.directory
        }

        if c.category
          existing_assigned[c.category.id] = true
          update_params = filter_update c.category, update_params
          if next update_params
            c.category\update update_params
        else
          c.category = Categories\create update_params

      -- create children
      for c in *filtered
        if c.children and next c.children
          set_children c.category, c.children

    set_children @category, @params.categories
    orphans = for c in *existing
      continue if existing_assigned[c.id]
      c

    archived = for o in *orphans
      if o.topics_count > 0
        o\update filter_update o, {
          archived: true
          hidden: true
          parent_category_id: @category.id
          position: Categories\next_position @category.id
        }
        o
      else
        o\delete!
        continue

    true, archived

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

