
import Flow from require "lapis.flow"

db = require "lapis.db"
import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import filter_update from require "community.helpers.models"

import trim_filter from require "lapis.util"

import PostReports from require "community.models"

limits = require "community.limits"

class ReportsFlow extends Flow
  expose_assigns: true

  new: (req) =>
    super req
    assert @current_user, "missing current user for reports flow"

  load_post: =>
    assert_valid @params, {
      {"post_id", is_integer: true}
    }

    PostsFlow = require "community.flows.posts"
    PostsFlow(@)\load_post!

    @topic = @post\get_topic!

    assert_error @post\allowed_to_report(@current_user),
      "invalid post"


  validate_params: =>
    @load_post!

    assert_valid @params, {
      {"report", type: "table"}
    }

    params = trim_filter @params.report, {
      "reason", "body"
    }

    assert_valid params, {
      {"reason", one_of: PostReports.reasons}
      {"body", optional: true, max_length: limits.MAX_BODY_LEN}
    }

    params.reason = PostReports.reasons\for_db params.reason
    params

  update_or_create_report: =>
    @load_post!
    @report = PostReports\find {
      user_id: @current_user.id
      post_id: @post.id
    }

    params = @validate_params!

    if @report
      @report\update filter_update @report, params
    else
      params.user_id = @current_user.id
      params.post_id = @post.id
      params.category_id = @topic.category_id
      @report = PostReports\create params

    true

  moderate_report: =>
    assert_valid @params, {
      {"report_id", is_integer: true}
      {"report", type: "table"}
    }

    @report = assert_error PostReports\find(@params.report_id)
    topic = @report\get_post!\get_topic!

    assert_error topic\allowed_to_moderate(@current_user), "invalid report"

    report = trim_filter @params.report
    assert_valid report, {
      {"status", one_of: PostReports.statuses}
    }

    @report\update {
      status: PostReports.statuses\for_db report.status
      moderating_user_id: @current_user.id
    }
    true


