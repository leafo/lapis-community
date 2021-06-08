import Flow from require "lapis.flow"

import Users from require "models"
import Categories, Posts, CategoryMembers, ActivityLogs from require "community.models"

import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import slugify from require "lapis.util"

import assert_page, require_login from require "community.helpers.app"
import filter_update from require "community.helpers.models"

import preload from require "lapis.db.model"

limits = require "community.limits"

db = require "lapis.db"

shapes = require "community.helpers.shapes"
import types from require "tableshape"

CATEOGRY_VALIDATION = {
  {"title",                    shapes.limited_text limits.MAX_TITLE_LEN}
  {"short_description",        shapes.db_nullable shapes.limited_text(limits.MAX_TITLE_LEN)}
  {"description",              shapes.db_nullable shapes.limited_text(limits.MAX_BODY_LEN)}

  -- these can be nulled out to inherit from parent/default
  {"membership_type",          shapes.db_nullable shapes.db_enum Categories.membership_types}
  {"voting_type",              shapes.db_nullable shapes.db_enum Categories.voting_types}
  {"topic_posting_type",       shapes.db_nullable shapes.db_enum Categories.topic_posting_types}

  {"archived",                 shapes.empty / false + types.any / true}
  {"hidden",                   shapes.empty / false + types.any / true}
  {"rules",                    shapes.db_nullable shapes.limited_text limits.MAX_BODY_LEN }

  {"type",                     shapes.empty + types.one_of { "directory", "post_list" }}
}

TAG_VALIDATION = {
  {"id",                       shapes.db_id + shapes.empty}
  {"label",                    shapes.limited_text limits.MAX_TAG_LEN}
  {"description",              shapes.db_nullable shapes.limited_text(80)}
  {"color",                    shapes.db_nullable shapes.color}
}

CATEGORY_CHILD_VALIDATION = {
  {"id",                       shapes.db_id + shapes.empty}
  {"title",                    shapes.limited_text limits.MAX_TITLE_LEN}
  {"short_description",        shapes.db_nullable shapes.limited_text(limits.MAX_TITLE_LEN)}
  {"archived",                 shapes.empty / false + types.any / true}
  {"hidden",                   shapes.empty / false + types.any / true}
  {"directory",                shapes.empty / false + types.any / true}
  {"children",                 shapes.empty + types.table}
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

    params = shapes.assert_valid @params, {
      {"category_id", shapes.db_id}
    }

    @category = Categories\find params.category_id
    assert_error @category, "invalid category"

  recent_posts: (opts) =>
    @load_category!
    assert_error @category\allowed_to_view(@current_user, @_req), "invalid category"
    assert_error @category\should_log_posts!, "category has no log"

    import CategoryPostLogs from require "community.models"
    import OrderedPaginator from require "lapis.db.pagination"

    clauses = {
      db.interpolate_query "category_id = ?", @category.id
    }

    if f = opts and opts.filter
      switch opts and opts.filter
        when "topics"
          table.insert clauses, "posts.post_number = 1 and posts.depth = 1"
        when "replies"
          table.insert clauses, "(posts.post_number > 1 or posts.depth > 1)"
        else
          error "unknown filter: #{f}"

    if opts and opts.after_date
      table.insert clauses,
        db.interpolate_query "(select created_at from #{db.escape_identifier Posts\table_name!} as posts where posts.id = post_id) > ?", opts.after_date

    query = "inner join #{db.escape_identifier Posts\table_name!} as posts on posts.id = post_id
      where #{table.concat clauses, " and "}"

    @pager = OrderedPaginator CategoryPostLogs, "post_id", query, {
      -- fields: "row_to_json(posts) as post"
      fields: "post_id"
      per_page: opts and opts.per_page or limits.TOPICS_PER_PAGE
      order: "desc"
      prepare_results: (logs) ->
        preload logs, "post"
        posts = [log\get_post! for log in *logs when log\get_post!]
        @preload_post_log posts
        posts
    }

    @posts, @next_page_id = @pager\get_page opts and opts.page
    true

  preload_post_log: (posts) =>
    import Posts, Topics, Categories from require "community.models"
    BrowsingFlow = require "community.flows.browsing"

    preload posts, "user", topic: "category"

    topics = [post\get_topic! for post in *posts]
    Topics\preload_bans topics, @current_user
    Categories\preload_bans [t\get_category! for t in *topics], @current_user

    BrowsingFlow(@)\preload_topics topics
    true

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
    ", db.list(category_ids), {
      per_page: 50
      prepare_results: (logs) ->
        preload logs, "object", "user", log_objects: "object"
        logs
    }

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
        preload pending, "category", "user", "topic", "parent_post"
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
        @pending_post\promote @
      when "deleted", "spam"
        @pending_post\update {
          status: PendingPosts.statuses\for_db @params.action
        }

    true, @post

  -- this will only validate fields in the array if provided, suitable for partial updates
  -- otherwise, every field n CATEOGRY_VALIDATION will be validated
  validate_params: (fields_list) =>
    validation = if fields_list
      out = for field in *fields_list
        local found
        for v in *CATEOGRY_VALIDATION
          if v[1] == field
            found = v
            break

        unless found
          error "tried to validate for invalid field: #{field}"

        found
      error "no fields to validate" unless next out
      out
    else
      CATEOGRY_VALIDATION

    params = shapes.assert_valid @params.category or {}, validation

    if params.type
      if @category
        assert_error not @category.parent_category_id,
          "only root category can have type set"

      params.directory = params.type == "directory"
      params.type = nil

    if params.title
      params.slug = slugify params.title

    params

  new_category: require_login (...) =>
    create_params = @validate_params ...
    create_params.user_id = @current_user.id
    @category = Categories\create create_params

    ActivityLogs\create {
      user_id: @current_user.id
      object: @category
      action: "create"
    }

    @category

  -- category_tags[1][label] = "what"
  -- category_tags[1][id] = 1123
  -- category_tags[2][label] = "new one"
  -- category_tags[2][description] = "hello"
  set_tags: require_login =>
    @load_category!
    assert_error @category\allowed_to_edit(@current_user), "invalid category"

    import convert_arrays from require "community.helpers.app"
    convert_arrays @params

    @params.category_tags or= {}

    assert_valid @params, {
      {"category_tags", type: "table"}
    }

    existing_tags = @category\get_tags!
    existing_by_id = {t.id, t for t in *existing_tags}

    import CategoryTags from require "community.models"

    actions = {}
    used_slugs = {}

    for position, tag_params in ipairs @params.category_tags
      tag = shapes.assert_valid tag_params, TAG_VALIDATION, {
        prefix: "topic tag #{position}"
      }
      tag.tag_order = position

      tag.slug = CategoryTags\slugify tag.label

      continue if tag.slug == ""
      continue if used_slugs[tag.slug]
      used_slugs[tag.slug] = true

      if tag.id
        existing = existing_by_id[tag.id]
        continue unless existing
        existing_by_id[tag.id] = nil
        tag.id = nil -- don't pass id to the update

        if tag.slug == tag.label
          tag.label = db.NULL

        table.insert actions, ->
          existing\update filter_update existing, tag
      else
        tag.category_id = @category.id

        table.insert actions, ->
          CategoryTags\create tag

    for _, old in pairs existing_by_id
      old\delete!

    for a in *actions
      a!

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

    assert_categores_length = (categories) ->
      assert_error #categories <= limits.MAX_CATEGORY_CHILDREN,
        "category can have at most #{limits.MAX_CATEGORY_CHILDREN} children"

    validate_category_params = (params, depth=1) ->
      assert_error depth <= limits.MAX_CATEGORY_DEPTH,
        "category depth must be at most #{limits.MAX_CATEGORY_DEPTH}"

      out = shapes.assert_valid params, CATEGORY_CHILD_VALIDATION

      if out.children
        assert_categores_length out.children

        out.children = for child in *out.children
          validate_category_params child, depth + 1

      out

    assert_categores_length @params.categories

    initial_depth = #@category\get_ancestors! + 1
    categories = for category in *@params.categories
      validate_category_params category, initial_depth

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
          short_description: c.short_description
          hidden: c.hidden
          archived: c.archived
          directory: c.directory
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

    set_children @category, categories

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

  edit_category: require_login (fields_list) =>
    @load_category!
    assert_error @category\allowed_to_edit(@current_user), "invalid category"

    update_params = @validate_params fields_list
    update_params = filter_update @category, update_params

    @category\update update_params
    @set_tags!

    if next update_params
      ActivityLogs\create {
        user_id: @current_user.id
        object: @category
        action: "edit"
      }

    true

