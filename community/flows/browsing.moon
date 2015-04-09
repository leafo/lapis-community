
import Flow from require "lapis.flow"

import Categories, Topics, Posts, Users from require "models"
import OrderedPaginator from require "lapis.db.pagination"

import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"

date = require "date"

class BrowsingFlow extends Flow
  expose_assigns: true

  set_before_after: =>
    assert_valid @params, {
      {"before", optional: true, is_integer: true}
      {"after", optional: true, is_integer: true}
    }

    @before = tonumber @params.before
    @after = tonumber @params.after

  topic_posts: =>
    assert_valid @params, {
      {"topic_id", is_integer: true }
    }

    @set_before_after!

    @topic = Topics\find @params.topic_id
    assert_error @topic\allowed_to_view @current_user

    import OrderedPaginator from require "lapis.db.pagination"
    pager = OrderedPaginator Posts, "post_number", [[
      where topic_id = ?
    ]], @topic.id, {
      per_page: 20
      prepare_results: (posts) ->
        Users\include_in posts, "user_id"
        posts
    }

    if @before
      pager\before @before
    else
      pager\after @after

  category_topics: =>
    assert_valid @params, {
      {"category_id", is_integer: true }
    }

    @set_before_after!

    @category = Categories\find @params.category_id
    assert_error @category\allowed_to_view @current_user

    import OrderedPaginator from require "lapis.db.pagination"
    pager = OrderedPaginator Topics, {"last_post_at", "id"}, [[
      where category_id = ? and not deleted
    ]], @category.id, {
      per_page: 20
      prepare_results: (topics) ->
        Users\include_in topics, "user_id"
        topics
    }

    topics, after_date, after_id = if @before
      pager\before @before
    else
      pager\after @after

    after_date = if after_date then (date(after_date) - date\epoch!)\spanseconds!
    topics, after_date, after_id

