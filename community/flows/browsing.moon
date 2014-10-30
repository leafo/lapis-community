
import Flow from require "lapis.flow"

import Topics, Posts, Users from require "models"
import OrderedPaginator from require "lapis.db.pagination"

import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"

class Browsing extends Flow
  topic_posts: =>
    assert_valid @params, {
      {"topic_id", is_integer: true }
      {"before", optional: true, is_integer: true}
      {"after", optional: true, is_integer: true}
    }

    @topic = Topics\find @params.topic_id
    assert_error @topic\allowed_to_view @current_user

    before = tonumber @params.before
    after = tonumber @params.after

    unless before or after
      after = 0

    import OrderedPaginator from require "lapis.db.pagination"
    pager = OrderedPaginator Posts, "post_number", [[
      where topic_id = ?
    ]], @topic.id, {
      order: after and "ASC" or "DESC"
      per_page: 20
      prepare_results: (posts) ->
        Users\include_in posts, "user_id"
        posts
    }

    pager\get_page after or before
