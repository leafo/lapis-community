import Flow from require "lapis.flow"

import Users from require "models"
import Categories, Posts, CategoryMembers, ActivityLogs from require "community.models"

import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import slugify from require "lapis.util"

import assert_page, require_current_user from require "community.helpers.app"
import filter_update from require "community.helpers.models"

import preload from require "lapis.db.model"

limits = require "community.limits"

db = require "lapis.db"

shapes = require "community.helpers.shapes"
types = require "lapis.validate.types"

split_field = (fields, name) ->
  if fields
    for f in *fields
      if f == name
        return true, [ff for ff in *fields when ff != name]

    false, fields

  true, fields

nullable_html = (t) ->
  shapes.empty_html / db.NULL + t

class CategoriesFlow extends Flow
  @CATEGORY_VALIDATION: {
    {"title",                    types.limited_text limits.MAX_TITLE_LEN}
    {"short_description",        shapes.db_nullable types.limited_text(limits.MAX_TITLE_LEN)}
    {"description",              nullable_html types.limited_text(limits.MAX_BODY_LEN)}

    -- these can be nulled out to inherit from parent/default
    {"membership_type",          shapes.db_nullable types.db_enum Categories.membership_types}
    {"voting_type",              shapes.db_nullable types.db_enum Categories.voting_types}
    {"topic_posting_type",       shapes.db_nullable types.db_enum Categories.topic_posting_types}
    {"approval_type",            shapes.db_nullable types.db_enum Categories.approval_types}

    {"archived",                 types.empty / false + types.any / true}
    {"hidden",                   types.empty / false + types.any / true}
    {"rules",                    nullable_html types.limited_text limits.MAX_BODY_LEN }

    {"type",                     types.empty + types.one_of { "directory", "post_list" }}
  }

  @TAG_VALIDATION: {
    {"id",                       types.db_id + types.empty}
    {"label",                    types.limited_text limits.MAX_TAG_LEN}
    {"description",              shapes.db_nullable types.limited_text(80)}
    {"color",                    shapes.db_nullable shapes.color}
  }

  @CATEGORY_CHILD_VALIDATION: {
    {"id",                       types.db_id + types.empty}
    {"title",                    types.limited_text limits.MAX_TITLE_LEN}
    {"short_description",        shapes.db_nullable types.limited_text(limits.MAX_TITLE_LEN)}
    {"archived",                 types.empty / false + types.any / true}
    {"hidden",                   types.empty / false + types.any / true}
    {"directory",                types.empty / false + types.any / true}
    {"children",                 types.empty + types.table}
  }

  expose_assigns: true

  moderators_flow: =>
    @load_category!
    ModeratorsFlow = require "community.flows.moderators"
    ModeratorsFlow @, @category

  members_flow: =>
    @load_category!
    MembersFlow = require "community.flows.members"
    MembersFlow @

  bans_flow: =>
    @load_category!
    BansFlow = require "community.flows.bans"
    BansFlow @, @category

  load_category: =>
    return if @category

    params = assert_valid @params, types.params_shape {
      {"category_id", types.db_id}
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

    params = assert_valid @params, types.params_shape {
      {"status", shapes.default("pending") * types.db_enum PendingPosts.statuses }
    }

    assert_page @

    @pager = PendingPosts\paginated "
      where ?
      order by id asc
    ", db.clause({
      category_id: @category.id
      status: params.status
    }) , {
      prepare_results: (pending) ->
        preload pending, "category", "user", "topic", "parent_post"
        pending
    }

    @pending_posts = @pager\get_page @page
    @pending_posts

  -- this is for a moderator eding a pending post in a category
  edit_pending_post: =>
    import PendingPosts from require "community.models"

    @load_category!

    params = assert_valid @params, types.params_shape {
      {"pending_post_id", types.db_id}
      {"action", types.one_of {
        "promote"
        "deleted"
        "spam"
      }}
    }

    @pending_post = PendingPosts\find params.pending_post_id
    assert_error @pending_post, "invalid pending post"
    category_id = @pending_post.category_id or @pending_post\get_topic!.category_id
    assert_error category_id == @category.id, "invalid pending post for category"
    assert_error @pending_post\allowed_to_moderate(@current_user), "invalid pending post"

    @post = switch params.action
      when "promote"
        @pending_post\promote @
      when "deleted", "spam"
        @pending_post\update {
          status: PendingPosts.statuses\for_db params.action
        }

    true, @post

  -- this will only validate fields in the array if provided, suitable for partial updates
  -- otherwise, every field n CATEGORY_VALIDATION will be validated
  validate_params: (fields_list) =>
    validation = if fields_list
      out = for field in *fields_list
        local found
        for v in *@@CATEGORY_VALIDATION
          if v[1] == field
            found = v
            break

        unless found
          error "tried to validate for invalid field: #{field}"

        found
      error "no fields to validate" unless next out
      out
    else
      @@CATEGORY_VALIDATION

    params = assert_valid @params.category or {}, types.params_shape validation

    if params.type
      if @category
        assert_error not @category.parent_category_id,
          "only root category can have type set"

      params.directory = params.type == "directory"
      params.type = nil

    if params.title
      params.slug = slugify params.title

    params

  new_category: require_current_user (...) =>
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
  set_tags: require_current_user =>
    @load_category!
    assert_error @category\allowed_to_edit(@current_user), "invalid category"

    {:category_tags} = assert_valid @params, types.params_shape {
      {"category_tags", shapes.default(-> {}) * shapes.convert_array}
    }

    existing_tags = @category\get_tags!
    existing_by_id = {t.id, t for t in *existing_tags}

    import CategoryTags from require "community.models"

    actions = {}
    used_slugs = {}

    made_change = false

    for position, tag_params in ipairs category_tags
      tag = assert_valid tag_params, types.params_shape @@TAG_VALIDATION, {
        error_prefix: "topic tag #{position}"
      }
      tag.tag_order = position

      tag.slug = CategoryTags\slugify tag.label

      continue unless tag.slug
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
          if existing\update filter_update existing, tag
            made_change = true
      else
        tag.category_id = @category.id

        table.insert actions, ->
          CategoryTags\create tag
          made_change = true

    for _, old in pairs existing_by_id
      if old\delete!
        made_change = true

    for a in *actions
      a!

    made_change

  -- categories[1][title] = "hello!"
  -- categories[1][children][1][title] = "a child!"
  -- categories[2][title] = "reused category"
  -- categories[2][id] = "1234"
  set_children: require_current_user =>
    @load_category!
    assert_error @category\allowed_to_edit(@current_user), "invalid category"

    local convert_children
    convert_children = types.array_of types.partial {
      children: types.empty + shapes.convert_array * types.proxy -> convert_children
    }

    params = assert_valid @params, types.params_shape {
      {"categories", shapes.default(-> {}) * shapes.convert_array * convert_children}
    }

    assert_categores_length = (categories) ->
      assert_error #categories <= limits.MAX_CATEGORY_CHILDREN,
        "category can have at most #{limits.MAX_CATEGORY_CHILDREN} children"

    validate_category_params = (params, depth=1) ->
      assert_error depth <= limits.MAX_CATEGORY_DEPTH,
        "category depth must be at most #{limits.MAX_CATEGORY_DEPTH}"

      out = assert_valid params, types.params_shape @@CATEGORY_CHILD_VALIDATION

      if out.children
        assert_categores_length out.children

        out.children = for child in *out.children
          validate_category_params child, depth + 1

      out

    assert_categores_length params.categories

    initial_depth = #@category\get_ancestors! + 1
    categories = for category in *params.categories
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

    to_delete = {}
    archived = {}

    -- archive the orphans that have topics, delete the empty ones
    -- Note: we do this in two phases to move deeply nested categories to the
    -- top before deleting empty ones, as deleting a cascades to all current children

    for o in *orphans
      if o.topics_count > 0
        table.insert archived, o
        o\update filter_update o, {
          archived: true
          hidden: true
          parent_category_id: @category.id
          position: Categories\next_position @category.id
        }
      else
        table.insert to_delete, o
        continue

    for cat in *to_delete
      cat\delete "hard"

    true, archived

  -- fields_list: can contain any name from CATEGORY_VALIDATION, or "category_tags"
  edit_category: require_current_user (fields_list) =>
    @load_category!
    assert_error @category\allowed_to_edit(@current_user), "invalid category"

    category_updated = false

    update_tags, fields_list = split_field fields_list, "category_tags"

    updated_fields = {}

    if not fields_list or next fields_list
      update_params = @validate_params fields_list
      update_params = filter_update @category, update_params
      if @category\update update_params
        for k in pairs update_params
          table.insert updated_fields, k

        category_updated = true

    if update_tags
      if @set_tags!
        table.insert updated_fields, "category_tags"
        category_updated = true

    if category_updated
      table.sort updated_fields
      ActivityLogs\create {
        user_id: @current_user.id
        object: @category
        action: "edit"
        data: {
          fields: updated_fields
        }
      }

    true

