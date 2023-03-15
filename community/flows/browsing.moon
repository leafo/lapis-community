
import Flow from require "lapis.flow"

import Users from require "models"
import Categories, Topics, Posts, CommunityUsers from require "community.models"
import OrderedPaginator from require "lapis.db.pagination"
import NestedOrderedPaginator from require "community.model"

import assert_error from require "lapis.application"
import assert_valid, with_params from require "lapis.validate"
import uniqify from require "lapis.util"

import preload from require "lapis.db.model"

db = require "lapis.db"
types = require "lapis.validate.types"
date = require "date"
limits = require "community.limits"

class BrowsingFlow extends Flow
  expose_assigns: true

  -- extension point for testing object visibiliy
  allowed_to_view: (obj) =>
    obj\allowed_to_view @current_user, @_req

  throttle_view_count: (key) =>
    false

  get_before_after: with_params {
    {"before", types.empty + types.db_id}
    {"after", types.empty + types.db_id}
  }, (params) => params.before, params.after

  view_counter: =>
    import running_in_test from require "lapis.spec"
    in_test = running_in_test!

    dict_name = if in_test
      nil
    else
      config = require("lapis.config").get!
      return unless config.community
      config.community.view_counter_dict

    import AsyncCounter, bulk_increment from require "community.helpers.counters"

    AsyncCounter dict_name, {
      increment_immediately: in_test
      sync_types: {
        topic: (updates) ->
          bulk_increment Topics, "views_count", updates

        category: (updates) ->
          bulk_increment Categories, "views_count", updates
      }
    }

  topic_pending_posts: =>
    TopicsFlow = require "community.flows.topics"
    TopicsFlow(@)\load_topic!

    return unless @current_user
    import PendingPosts from require "community.models"
    @pending_posts = PendingPosts\select "where topic_id = ? and user_id = ?", @topic.id, @current_user.id
    @pending_posts


  increment_topic_view_counter: (topic=@topic)=>
    assert topic, "missing topic"
    if view_counter = @view_counter!
      key = "topic:#{topic.id}"
      unless @throttle_view_count key
        view_counter\increment key

  topic_posts: (opts={}) =>
    mark_seen = if opts.mark_seen == nil
      true
    else
      opts.mark_seen

    order = opts.order or "asc"

    per_page = opts.per_page or limits.POSTS_PER_PAGE

    TopicsFlow = require "community.flows.topics"
    TopicsFlow(@)\load_topic!

    assert_error @allowed_to_view(@topic), "not allowed to view"

    if opts.increment_views != false
      @increment_topic_view_counter!

    before, after = @get_before_after!

    params = assert_valid @params, types.params_shape {
      {"status", (types.empty / "default" + types.one_of({"archived"})) * types.db_enum Posts.statuses}
    }

    pager = NestedOrderedPaginator Posts, "post_number", "where ?", db.clause({
      topic_id: @topic.id
      status: params.status
      depth: 1
    }), {
      :per_page

      parent_field: "parent_post_id"
      child_clause: {
        status: params.status
      }

      sort: (list) ->
        table.sort list, (a,b) ->
          a.post_number < b.post_number

      prepare_results: @\preload_posts
    }

    min_range, max_range = @topic\get_root_order_ranges!

    switch order
      when "asc"
        if before
          @posts = pager\before before
          -- reverse it
          @posts = [@posts[i] for i=#@posts,1,-1]
        else
          @posts = pager\after after

        next_after = if p = @posts[#@posts]
          p.post_number

        next_after = nil if next_after == max_range

        next_before = if p = @posts[1]
          p.post_number

        next_before = nil if next_before == min_range

        if next_after
          @next_page = {
            after: next_after
          }

          @last_page = {
            before: max_range + 1
          }

        if next_before
          -- we remove before and give empty params so first page just goes to plain URL
          @prev_page = {
            before: next_before > per_page + 1 and next_before or nil
          }

      when "desc"
        if after
          @posts = pager\after after
          @posts = [@posts[i] for i=#@posts,1,-1]
        else
          @posts = pager\before before

        next_before = if p = @posts[#@posts]
          p.post_number

        next_before = nil if next_before == min_range

        next_after = if p = @posts[1]
          p.post_number

        next_after = nil if next_after == max_range

        if next_before
          @next_page = { before: next_before }
          @last_page = { after: 0}

        @prev_page = { after: next_after } if next_after
      else
        error "unknown order: #{order}"

    if mark_seen and @current_user
      import UserTopicLastSeens from require "community.models"
      last_seen = UserTopicLastSeens\find {
        user_id: @current_user.id
        topic_id: @topic.id
      }

      if not last_seen or last_seen.post_id != @topic.last_post_id
        @topic\set_seen @current_user

  preload_categories: (categories, last_seens=true) =>
    preload categories, "last_topic"
    topics = [c.last_topic for c in *categories when c.last_topic]
    @preload_topics topics

    if last_seens and @current_user
      preload [c\with_user(@current_user.id) for c in *categories], "last_seen"

    categories

  preload_topics: (topics, last_seens=true) =>
    Topics\preload_relation topics, "last_post", {
      fields: "id, user_id, created_at, updated_at"
    }

    all_topics = [t for t in *topics]
    for t in *topics
      if t.last_post
        table.insert all_topics, t.last_post

    preload all_topics, "user"

    if last_seens and @current_user
      preload [t\with_user(@current_user.id) for t in *topics], "last_seen"

    topics

  preload_posts: (posts) =>
    preload posts, "user", "moderation_log"

    for p in *posts
      p.topic = @topic

    Posts\preload_mentioned_users posts
    CommunityUsers\preload_users [p.user for p in *posts when p.user]

    if @current_user
      import Blocks, Votes from require "community.models"

      viewers = [post\with_viewing_user(@current_user.id) for post in *posts]
      preload viewers, "block"
      Votes\preload_post_votes posts, @current_user.id

    posts

  -- TODO: there is no pagination here yet
  sticky_category_topics: (opts={}) =>
    CategoriesFlow = require "community.flows.categories"
    CategoriesFlow(@)\load_category!
    assert_error @allowed_to_view(@category), "not allowed to view"

    pager = OrderedPaginator Topics, "category_order", [[
      where category_id = ? and status = ? and not deleted and sticky
    ]], @category.id, Topics.statuses.default, {
      per_page: opts.per_page or limits.TOPICS_PER_PAGE
      prepare_results: @\preload_topics
    }

    @sticky_topics = pager\before!

  -- get's posts from all subcategories
  preview_category_topics: (@category, limit=5) =>
    assert @category, "missing category"
    status = Topics.statuses\for_db "default"
    ids = [c.id for c in *@category\get_flat_children!]

    table.insert ids, @category.id

    import encode_value_list from require "community.helpers.models"

    -- TODO: check query indexe because of sticky
    topic_tuples = db.query "
      select unnest(array(
        select row_to_json(community_topics) from community_topics
        where category_id = t.category_id
        and status = ?
        and not deleted
        and last_post_id is not null
        order by category_order desc
        limit ?
      )) as topic
      from (#{encode_value_list [{id} for id in *ids]}) as t(category_id)
    ", Topics.statuses.default, limit

    table.sort topic_tuples, (a,b) ->
      a.topic.last_post_id > b.topic.last_post_id

    topics = [Topics\load(t.topic) for t in *topic_tuples[1,limit] when t]
    @preload_topics topics

    topics

  category_topics: (opts={}) =>
    mark_seen = if opts.mark_seen == nil
      true
    else
      opts.mark_seen

    CategoriesFlow = require "community.flows.categories"
    CategoriesFlow(@)\load_category!
    assert_error @allowed_to_view(@category), "not allowed to view"

    params = assert_valid @params, types.params_shape {
      {"status", (types.empty / "default" + types.one_of({"archived", "hidden"})) * types.db_enum Topics.statuses}
    }

    @topics_status = Topics.statuses\to_name params.status

    status = Topics.statuses\for_db @topics_status

    if opts.increment_views != false
      if view_counter = @view_counter!
        key = "category:#{@category.id}"
        unless @throttle_view_count key
          view_counter\increment key

    before, after = @get_before_after!

    pager = OrderedPaginator Topics, "category_order", "where ?", db.clause({
      category_id: @category.id
      status: params.status
      deleted: false
      sticky: false
    }), {
      per_page: opts.per_page or limits.TOPICS_PER_PAGE
      prepare_results: @\preload_topics
    }

    if after
      @topics = pager\after after
      -- reverse it
      @topics = [@topics[i] for i=#@topics,1,-1]
    else
      @topics = pager\before before

    ranges = @category\get_order_ranges status
    min, max = ranges.regular.min, ranges.regular.max

    next_after = if t = @topics[1]
      t.category_order

    next_after = nil if max and next_after and next_after >= max

    next_before = if t = @topics[#@topics]
      t.category_order

    next_before = nil if min and next_before and next_before <= min

    @next_page = { before: next_before } if next_before
    @prev_page = { after: next_after } if next_after

    if mark_seen
      last_seen = @category\find_last_seen_for_user @current_user
      if not last_seen or last_seen\should_update!
        @category\set_seen @current_user

    @topics

  -- this is like getting topic posts but with a single root post
  post_single: (post) =>
    @post or= post
    PostsFlow = require "community.flows.posts"
    PostsFlow(@)\load_post!

    @topic = @post\get_topic!

    assert_error @allowed_to_view(@post), "not allowed to view"

    -- if the post is archived then we should include both archived and non-archived
    status = if @post\is_archived!
      db.list { Posts.statuses.archived, Posts.statuses.default }
    else
      db.list { @post.status }

    local all_posts

    pager = NestedOrderedPaginator Posts, "post_number", [[
      where parent_post_id = ? and status in ?
    ]], @post.id, status, {
      per_page: limits.POSTS_PER_PAGE

      parent_field: "parent_post_id"

      child_clause: {
        status: status
      }

      sort: (list) ->
        table.sort list, (a,b) ->
          a.post_number < b.post_number

      is_top_level_item: (post) ->
        post.parent_post_id == @post.id

      prepare_results: (posts) ->
        all_posts = [p for p in *posts]
        posts
    }

    children = pager\get_page!

    if all_posts
      table.insert all_posts, @post
    else
      all_posts = { @post }

    @preload_posts all_posts
    @post.children = children
    true

  category_single: =>
    CategoriesFlow = require "community.flows.categories"
    CategoriesFlow(@)\load_category!
    assert_error @allowed_to_view(@category), "not allowed to view"

    @category\get_children prepare_results: @\preload_categories
    true


