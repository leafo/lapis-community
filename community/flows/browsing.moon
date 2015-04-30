
import Flow from require "lapis.flow"

import Categories, Topics, Posts, Users from require "models"
import OrderedPaginator from require "lapis.db.pagination"

import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"

db = require "lapis.db"

date = require "date"

PER_PAGE = 20

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

    import OrderedPaginator from require "lapis.db.pagination"
    pager = OrderedPaginator Posts, "post_number", [[
      where topic_id = ? and depth = 1
    ]], @topic.id, {
      per_page: PER_PAGE
      prepare_results: (posts) ->
        Users\include_in posts, "user_id"
        for p in *posts
          p.topic = @topic

        if @current_user
          import PostVotes from require "models"

          PostVotes\include_in posts, "post_id", {
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

    import OrderedPaginator from require "lapis.db.pagination"
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

