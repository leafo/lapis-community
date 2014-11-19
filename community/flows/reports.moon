
import Flow from require "lapis.flow"

db = require "lapis.db"
import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"

import trim_filter from require "lapis.util"

import PostReports from require "models"

class Reports extends Flow
  new: (req) =>
    super req
    assert @current_user, "missing current user for post flow"

  new_report: =>
    assert_valid @params, {
      {"post_id", is_integer: true}
      {"report", type: "table"}
    }

    import Posts from require "models"

    @post = assert_error Posts\find(@params.post_id), "invalid post"
    @topic = @post\get_topic!
    assert_error @topic\allowed_to_view @current_user
    assert_error @post.user_id != @current_user_id, "invalid post"

    report = trim_filter @params.report
    assert_valid report, {
      {"reason", one_of: PostReports.reasons}
      {"body", optional: true, max_length: 1024*5}
    }

    @report = PostReports\create {
      user_id: @current_user.id
      post_id: @post.id
      category_id: @topic.category_id
      reason: report.reason
      body: report.body
    }

    true

