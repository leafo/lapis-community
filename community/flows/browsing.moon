
import Flow from require "lapis.flow"

import Users from require "models"
import Categories, Topics, Posts, CommunityUsers from require "community.models"
import OrderedPaginator from require "lapis.db.pagination"
import NestedOrderedPaginator from require "community.model"

import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import uniqify from require "lapis.util"

db = require "lapis.db"

date = require "date"
limits = require "community.limits"

class BrowsingFlow extends Flow
  expose_assigns: true

  throttle_view_count: (key) =>
    false

  get_before_after: =>
    assert_valid @params, {
      {"before", optional: true, is_integer: true}
      {"after", optional: true, is_integer: true}
    }

    tonumber(@params.before), tonumber(@params.after)

  view_counter: =>
    config = require("lapis.config").get!
    return unless config.community
    dict_name = config.community.view_counter_dict

    import AsyncCounter, bulk_increment from require "community.helpers.counters"

    AsyncCounter dict_name, {
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

  topic_posts: (opts={}) =>
    mark_seen = if opts.mark_seen == nil
      true
    else
      opts.mark_seen

    order = opts.order or "asc"

    per_page = opts.per_page or limits.POSTS_PER_PAGE

    TopicsFlow = require "community.flows.topics"
    TopicsFlow(@)\load_topic!
    assert_error @topic\allowed_to_view(@current_user), "not allowed to view"

    if view_counter = @view_counter!
      key = "topic:#{@topic.id}"
      unless @throttle_view_count key
        view_counter\increment key

    before, after = @get_before_after!

    assert_valid @params, {
      {"status", optional: true, one_of: {"archived"}}
    }

    status = Posts.statuses\for_db @params.status or "default"

    pager = NestedOrderedPaginator Posts, "post_number", [[
      where topic_id = ? and depth = 1 and status = ?
    ]], @topic.id, status, {
      :per_page

      parent_field: "parent_post_id"
      child_clause: {
        status: status
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

        @next_page = { before: next_before } if next_before
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
    Categories\preload_relations categories, "last_topic"
    topics = [c.last_topic for c in *categories when c.last_topic]
    @preload_topics topics

    if last_seens and @current_user
      import UserCategoryLastSeens from require "community.models"
      UserCategoryLastSeens\include_in categories, "category_id", flip: true, where: {
        user_id: @current_user.id
      }

    categories

  preload_topics: (topics, last_seens=true) =>
    Topics\preload_relations topics, "last_post"

    with_users = [t for t in *topics]
    for t in *topics
      if t.last_post
        table.insert with_users, t.last_post

    Users\include_in with_users, "user_id", for_relation: "user"

    if last_seens and @current_user
      import UserTopicLastSeens from require "community.models"
      UserTopicLastSeens\include_in topics, "topic_id", {
        flip: true
        where: {
          user_id: @current_user.id
        }
      }

    topics

  preload_posts: (posts) =>
    Posts\preload_relations posts, "user"
    for p in *posts
      p.topic = @topic

    Posts\preload_mentioned_users posts
    CommunityUsers\preload_users [p.user for p in *posts when p.user]

    if @current_user
      posts_with_votes = [p for p in *posts when p.down_votes_count > 0 or p.up_votes_count > 0]

      import Blocks, Votes from require "community.models"

      Votes\include_in posts_with_votes, "object_id", {
        flip: true
        where: {
          object_type: Votes.object_types.post
          user_id: @current_user.id
        }
      }

      Blocks\include_in posts, "blocked_user_id", {
        flip: true
        local_key: "user_id"
        where: {
          blocking_user_id: @current_user.id
        }
      }

    posts

  -- TODO: there is no pagination here yet
  sticky_category_topics: =>
    CategoriesFlow = require "community.flows.categories"
    CategoriesFlow(@)\load_category!

    pager = OrderedPaginator Topics, "category_order", [[
      where category_id = ? and status = ? and not deleted and sticky
    ]], @category.id, Topics.statuses.default, {
      per_page: limits.TOPICS_PER_PAGE
      prepare_results: @\preload_topics
    }

    @sticky_topics = pager\before!

  category_topics: (opts={}) =>
    mark_seen = if opts.mark_seen == nil
      true
    else
      opts.mark_seen

    CategoriesFlow = require "community.flows.categories"
    CategoriesFlow(@)\load_category!

    assert_valid @params, {
      {"status", optional: true, one_of: {"archived"}}
    }

    @topics_status = @params.status or "default"
    status = Topics.statuses\for_db @params.status or "default"

    if view_counter = @view_counter!
      key = "category:#{@category.id}"
      unless @throttle_view_count key
        view_counter\increment key

    before, after = @get_before_after!

    pager = OrderedPaginator Topics, "category_order", [[
      where category_id = ? and status = ? and not deleted and not sticky
    ]], @category.id, status, {
      per_page: limits.TOPICS_PER_PAGE
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

    assert_error @post\allowed_to_view(@current_user), "not allowed to view"

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

    @category\get_children prepare_results: @\preload_categories
    true


