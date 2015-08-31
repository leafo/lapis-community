
import Flow from require "lapis.flow"

db = require "lapis.db"
import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import filter_update from require "community.helpers.models"

import trim_filter from require "lapis.util"

import assert_page, require_login from require "community.helpers.app"

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

    -- get existing report
    @report = PostReports\find {
      user_id: @current_user.id
      post_id: @post.id
    }

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
    params = @validate_params!

    if @report
      @report\update filter_update @report, params
      "update"
    else
      params.user_id = @current_user.id
      params.post_id = @post.id
      params.category_id = @topic.category_id
      @report = PostReports\create params
      "create"

  show_reports: (category) =>
    assert category, "missing report object"
    assert_error category\allowed_to_moderate(@current_user), "invalid category"
    assert_page @

    assert_valid @params, {
      {"status", one_of: PostReports.statuses, optional: true}
    }

    filter = {
      status: @params.status and PostReports.statuses\for_db @params.status
    }

    @pager = PostReports\paginated "
      where category_id = ?
      #{next(filter) and "and " .. db.encode_clause(filter) or ""}
    ", category.id, prepare_results: (reports) ->
      import Posts, Topics from require "community.models"
      import Users from require "models"

      for report in *reports
        report.category = category

      Posts\include_in reports, "post_id"
      Topics\include_in [r.post for r in *reports], "topic_id"

      Users\include_in reports, "user_id"
      Users\include_in reports, "moderating_user_id"

    @reports = @pager\get_page!
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

    import ModerationLogs from require "community.models"

    ModerationLogs\create {
      user_id: @current_user.id
      object: @report
      category_id: @report.category_id
      action: "report.status(#{report.status})"
    }

    true


