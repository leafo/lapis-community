
import Flow from require "lapis.flow"

import Categories, Topics, Posts, Users from require "models"
import OrderedPaginator from require "lapis.db.pagination"

import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"

db = require "lapis.db"

date = require "date"

PER_PAGE = 20

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
        continue

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

  topic_posts: =>
    TopicsFlow = require "community.flows.topics"
    TopicsFlow(@)\load_topic!
    assert_error @topic\allowed_to_view(@current_user), "not allowed to view"

    before, after = @get_before_after!

    pager = NestedOrderedPaginator Posts, "post_number", [[
      where topic_id = ? and depth = 1
    ]], @topic.id, {
      per_page: PER_PAGE

      parent_field: "parent_post_id"
      sort: (list) ->
        table.sort list, (a,b) ->
          a.post_number < b.post_number

      prepare_results: (posts) ->
        Users\include_in posts, "user_id"
        for p in *posts
          p.topic = @topic

        if @current_user
          posts_with_votes = [p for p in *posts when p.down_votes_count > 0 or p.up_votes_count > 0]

          import PostVotes from require "models"

          PostVotes\include_in posts_with_votes, "post_id", {
            flip: true
            where: {
              user_id: @current_user.id
            }
          }

        posts
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

  category_topics: =>
    CategoriesFlow = require "community.flows.categories"
    CategoriesFlow(@)\load_category!
    assert_error @category\allowed_to_view(@current_user), "not allowed to view"

    before, after = @get_before_after!

    pager = OrderedPaginator Topics, "category_order", [[
      where category_id = ? and not deleted and not sticky
    ]], @category.id, {
      per_page: PER_PAGE
      prepare_results: (topics) ->
        Users\include_in topics, "user_id"
        topics
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

