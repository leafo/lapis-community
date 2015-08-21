
import Flow from require "lapis.flow"

import Users from require "models"
import Categories, Topics, Posts from require "community.models"
import OrderedPaginator from require "lapis.db.pagination"

import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import uniqify from require "lapis.util"

db = require "lapis.db"

date = require "date"
limits = require "community.limits"

class NestedOrderedPaginator extends OrderedPaginator
  prepare_results: (items) =>
    items = super items

    parent_field = @opts.parent_field
    child_field = @opts.child_field or "children"

    by_parent = {}

    -- sort and nest
    top_level = for item in *items
      if pid = item[parent_field]
        by_parent[pid] or= {}
        table.insert by_parent[pid], item

      if @opts.is_top_level_item
        continue unless @opts.is_top_level_item item
      else
        continue if item[parent_field]

      item

    for item in *items
      item[child_field] = by_parent[item.id]
      if children = @opts.sort and item[child_field]
        @opts.sort children

    top_level

  select: (q, opts) =>
    tname = db.escape_identifier @model\table_name!
    parent_field = assert @opts.parent_field, "missing parent_field"
    child_field = @opts.child_field or "children"

    res = db.query "
      with recursive nested as (
        (select * from #{tname} #{q})
        union
        select pr.* from #{tname} pr, nested
          where pr.#{db.escape_identifier parent_field} = nested.id
      )
      select * from nested
    "

    for r in *res
      @model\load r

    res

class BrowsingFlow extends Flow
  expose_assigns: true

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

  topic_posts: (mark_seen=true) =>
    TopicsFlow = require "community.flows.topics"
    TopicsFlow(@)\load_topic!
    assert_error @topic\allowed_to_view(@current_user), "not allowed to view"

    if view_counter = @view_counter!
      view_counter\increment "topic:#{@topic.id}"

    before, after = @get_before_after!

    pager = NestedOrderedPaginator Posts, "post_number", [[
      where topic_id = ? and depth = 1
    ]], @topic.id, {
      per_page: limits.POSTS_PER_PAGE

      parent_field: "parent_post_id"
      sort: (list) ->
        table.sort list, (a,b) ->
          a.post_number < b.post_number

      prepare_results: @\preload_posts
    }

    if before
      @posts = pager\before before
      -- reverse it
      @posts = [@posts[i] for i=#@posts,1,-1]
    else
      @posts = pager\after after

    @after = if p = @posts[#@posts]
      p.post_number

    @after = nil if @after == @topic.root_posts_count

    @before = if p = @posts[1]
      p.post_number

    @before = nil if @before == 1

    if mark_seen and @current_user
      import UserTopicLastSeens from require "community.models"
      last_seen = UserTopicLastSeens\find {
        user_id: @current_user.id
        topic_id: @topic.id
      }

      if not last_seen or last_seen.post_id != @topic.last_post_id
        @topic\set_seen @current_user

  preload_topics: (topics) =>
    Posts\include_in topics, "last_post_id"

    with_users = [t for t in *topics]
    for t in *topics
      if t.last_post
        table.insert with_users, t.last_post

    Users\include_in with_users, "user_id"

    if @current_user
      import UserTopicLastSeens from require "community.models"
      UserTopicLastSeens\include_in topics, "topic_id", flip: true, where: { user_id: @current_user.id }

    topics

  preload_posts: (posts) =>
    Users\include_in posts, "user_id"
    for p in *posts
      p.topic = @topic

    Posts\preload_mentioned_users posts

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
    pager = OrderedPaginator Topics, "category_order", [[
      where category_id = ? and not deleted and sticky
    ]], @category.id, {
      per_page: limits.TOPICS_PER_PAGE
      prepare_results: @\preload_topics
    }

    @sticky_topics = pager\get_page!

  category_topics: =>
    CategoriesFlow = require "community.flows.categories"
    CategoriesFlow(@)\load_category!
    assert_error @category\allowed_to_view(@current_user), "not allowed to view"

    if view_counter = @view_counter!
      view_counter\increment "category:#{@category.id}"

    before, after = @get_before_after!

    pager = OrderedPaginator Topics, "category_order", [[
      where category_id = ? and not deleted and not sticky
    ]], @category.id, {
      per_page: limits.TOPICS_PER_PAGE
      prepare_results: @\preload_topics
    }

    if after
      @topics = pager\after after
      -- reverse it
      @topics = [@topics[i] for i=#@topics,1,-1]
    else
      @topics = pager\before before

    ranges = @category\get_order_ranges!
    min, max = ranges.regular.min, ranges.regular.max

    @after = if t = @topics[1]
      t.category_order

    @after = nil if max and @after >= max

    @before = if t = @topics[#@topics]
      t.category_order

    @before = nil if min and @before <= min

    @topics

  -- this is like getting topic posts but with a single root post
  post_single: =>
    PostsFlow = require "community.flows.posts"
    PostsFlow(@)\load_post!
    @topic = @post\get_topic!

    assert_error @post\allowed_to_view(@current_user), "not allowed to view"

    local all_posts

    pager = NestedOrderedPaginator Posts, "post_number", [[
      where parent_post_id = ?
    ]], @post.id, {
      per_page: limits.POSTS_PER_PAGE

      parent_field: "parent_post_id"

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
