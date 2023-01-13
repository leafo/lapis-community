
import Flow from require "lapis.flow"

db = require "lapis.db"
import assert_error from require "lapis.application"
import assert_valid, with_params from require "lapis.validate"
import preload from require "lapis.db.model"

import filter_update from require "community.helpers.models"
import require_current_user, assert_page from require "community.helpers.app"

import PostReports, Posts, Topics from require "community.models"

limits = require "community.limits"

shapes = require "community.helpers.shapes"
types = require "lapis.validate.types"

class ReportsFlow extends Flow
  expose_assigns: true

  new: (req) =>
    super req
    assert @current_user, "missing current user for reports flow"

  find_report_for_moderation: with_params {
    {"report_id", types.db_id}
  }, (params) =>
    report = assert_error PostReports\find(@params.report_id), "invalid report"

    topic = report\get_post!\get_topic!
    assert_error topic\allowed_to_moderate(@current_user), "invalid report"

    @report = report
    report

  load_post: =>
    PostsFlow = require "community.flows.posts"
    PostsFlow(@)\load_post!

    @topic = @post\get_topic!

    assert_error @post\allowed_to_report(@current_user, @_req),
      "invalid post: not allowed to create report"

    -- get existing report
    @report = PostReports\find {
      user_id: @current_user.id
      post_id: @post.id
    }

  update_or_create_report: require_current_user =>
    @load_post!
    params = assert_valid @params.report, types.params_shape {
      {"reason", types.db_enum PostReports.reasons}
      {"body", shapes.db_nullable types.limited_text limits.MAX_BODY_LEN}
    }

    params = @copy_post_params params

    if @report
      @report\update filter_update @report, params
      "update"
    else
      params.user_id = @current_user.id
      params.post_id = @post.id
      params.category_id = @topic.category_id
      @report = PostReports\create params
      "create"

  copy_post_params: (params) =>
    out = {k,v for k,v in pairs params}
    out.post_user_id = @post.user_id
    out.post_topic_id = @post.topic_id
    out.post_body = @post.body
    out.post_body_format = @post.body_format
    out.post_parent_post_id = @post.parent_post_id

    out

  show_reports: require_current_user (category) =>
    assert category, "missing report object"
    assert_error category\allowed_to_moderate(@current_user), "invalid category"

    assert_page @

    params = assert_valid @params, types.params_shape {
      {"status", types.empty + types.db_enum PostReports.statuses}
    }

    children = @category\get_flat_children!
    category_ids = [c.id for c in *children]
    table.insert category_ids, @category.id

    where_clause = db.clause {
      db.clause {
        category_id: db.list category_ids
        status: params.status
      }, table_name: PostReports\table_name!

      db.clause {
        deleted: false
      }, table_name: "topics"

      db.clause {
        deleted: false
      }, table_name: "posts"
    }

    @pager = PostReports\paginated "
      inner join #{db.escape_identifier Posts\table_name!} as posts
        on posts.id = post_id

      inner join #{db.escape_identifier Topics\table_name!} as topics
        on posts.topic_id = topics.id

      where ? order by id desc
    ", where_clause, {
      fields: "#{db.escape_identifier PostReports\table_name!}.*"
      prepare_results: (reports) ->
        preload reports, "category", "user", "moderating_user", post: "topic"
        reports
      }

    @reports = @pager\get_page @page
    true

  moderate_report: require_current_user =>
    report = @find_report_for_moderation!

    {:action} = assert_valid @params, types.params_shape {
      {"action", types.empty / "update" + types.one_of {"update", "purge"}}
    }

    switch action
      when "purge"
        report\delete!
      when "update"
        report_update = assert_valid @params.report, types.params_shape {
          {"status", types.db_enum PostReports.statuses}
        }

        report\update {
          status: report_update.status
          moderating_user_id: @current_user.id
          moderated_at: db.format_date!
        }

        import ModerationLogs from require "community.models"

        ModerationLogs\create {
          user_id: @current_user.id
          object: report
          category_id: report.category_id
          action: "report.status(#{PostReports.statuses\to_name report.status})"
        }

    action


