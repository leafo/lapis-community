import Flow from require "lapis.flow"

import Users from require "models"
import Categories, Posts, CategoryMembers, ActivityLogs from require "community.models"

import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import trim_filter, slugify from require "lapis.util"

import assert_page, require_login from require "community.helpers.app"
import filter_update from require "community.helpers.models"

import preload from require "lapis.db.model"

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
      "type"
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

    if has_field.type
      if @category
        assert_error not @category.parent_category_id,
          "only root category can have type set"

      assert_valid category_params, {
        {"type", one_of: {
          "directory"
          "post_list"
        }}
      }

      category_params.directory = category_params.type == "directory"
      category_params.type = nil

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

  -- category_tags[1][label] = "what"
  -- category_tags[1][id] = 1123
  -- category_tags[2][label] = "new one"
  set_tags: require_login =>
    @load_category!
    assert_error @category\allowed_to_edit(@current_user), "invalid category"

    import convert_arrays from require "community.helpers.app"
    convert_arrays @params

    @params.category_tags or= {}

    assert_valid @params, {
      {"category_tags", type: "table"}
    }

    for tag in *@params.category_tags
      trim_filter tag, { "label", "id", "color" }
      assert_valid tag, {
        {"id", is_integer: true, optional: true}
        {"label",
          exists: "true", type: "string", max_length: limits.MAX_TAG_LEN
          "topic tag must be at most #{limits.MAX_TAG_LEN} charcaters"}
        {"color", is_color: true, optional: true}
      }

    existing_tags = @category\get_tags!
    existing_by_id = {t.id, t for t in *existing_tags}

    import CategoryTags from require "community.models"

    actions = {}
    used_slugs = {}

    for position, tag in ipairs @params.category_tags
      slug = CategoryTags\slugify tag.label
      continue if slug == ""
      continue if used_slugs[slug]
      used_slugs[slug] = true

      opts = {
        label: tag.label
        color: tag.color or db.NULL
        tag_order: position
      }

      if tid = tonumber tag.id
        existing = existing_by_id[tid]
        continue unless existing
        existing_by_id[tid] = nil

        opts.slug = slug
        if slug == opts.label
          opts.label = db.NULL

        table.insert actions, ->
          existing\update filter_update existing, opts
      else
        opts.category_id = @category.id

        table.insert actions, ->
          CategoryTags\create opts

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
        assert_categores_length params.children

        for child in *params.children
          validate_category_params child, depth + 1

    assert_categores_length @params.categories

    initial_depth = #@category\get_ancestors! + 1
    for category in *@params.categories
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
    @set_tags!

    if next update_params
      ActivityLogs\create {
        user_id: @current_user.id
        object: @category
        action: "edit"
      }

    true

