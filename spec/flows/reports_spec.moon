import in_request from require "spec.flow_helpers"

factory = require "spec.factory"

import types from require "tableshape"

describe "reports", ->
  local current_user

  import Users from require "spec.models"
  import Categories, Topics, Posts, PostReports, ModerationLogs from require "spec.community_models"

  before_each ->
    current_user = factory.Users!

  describe "report", ->
    update_or_create_report = (params) ->
      ReportsFlow = require "community.flows.reports"
      in_request { post: params }, =>
        @current_user = current_user
        ReportsFlow(@)\update_or_create_report!

    it "fails to create report without required parameters", ->
      assert.has_error(
        -> update_or_create_report {}
        { message: {"post_id: expected integer"} }
      )

    it "doesn't create report for own post", ->
      post = factory.Posts user_id: current_user.id

      assert.has_error(
        ->
          update_or_create_report {
            post_id: post.id
            "report[reason]": "other"
            "report[body]": "this is the problem"
          }
        {message: {"invalid post: not allowed to create report"}}
      )

      assert.same 0, PostReports\count!

    it "creates report", ->
      post = factory.Posts!

      action = update_or_create_report {
        post_id: post.id
        "report[reason]": "other"
        "report[body]": "this is the problem   \0  "
      }

      assert.same "create", action

      reports = PostReports\select!
      assert.same 1, #reports

      topic = post\get_topic!
      report = unpack reports

      assert_report = types.assert types.partial {
        body: "this is the problem"
        reason: PostReports.reasons.other
        status: PostReports.statuses.pending
        user_id: current_user.id
        post_id: post.id
        category_id: topic.category_id

        post_body_format: post.body_format
        post_body: post.body
        post_user_id: post.user_id
        post_topic_id: post.topic_id
      }

      assert_report report

    it "creates new report without body", ->
      post = factory.Posts!

      update_or_create_report {
        post_id: post.id
        "report[reason]": "other"
      }

      reports = PostReports\select!
      assert.same 1, #reports
      report = unpack reports

      assert.same nil, report.body


    it "creates new report for post in topic without category", ->
      topic = factory.Topics category: false
      post = factory.Posts topic_id: topic.id

      update_or_create_report {
        post_id: post.id
        "report[reason]": "other"
        "report[body]": "please report"
      }

      reports = PostReports\select!
      assert.same 1, #reports

      report = unpack reports
      assert.same nil, report.category_id
      assert.same post.id, report.post_id
      assert.same 0, report.category_report_number

    it "updates existing report", ->
      report = factory.PostReports user_id: current_user.id

      post = report\get_post!
      post\update {
        body: "here is a new body that should be copied into the report"
        parent_post_id: 999
      }

      action = update_or_create_report {
        post_id: report.post_id
        "report[reason]": "spam"
        "report[body]": "I am updating my report"
      }

      assert.same "update", action

      assert.same 1, PostReports\count!
      report = unpack PostReports\select!

      assert_report = types.assert types.partial {
        body: "I am updating my report"
        reason: PostReports.reasons.spam
        status: PostReports.statuses.pending
        user_id: current_user.id
        post_id: post.id

        post_body_format: post.body_format
        post_body: "here is a new body that should be copied into the report"
        post_user_id: post.user_id
        post_parent_post_id: 999
      }

      assert_report report

    it "updates report and removes empty body", ->
      report = factory.PostReports user_id: current_user.id

      update_or_create_report {
        post_id: report.post_id
        "report[reason]": "spam"
        "report[body]": ""
      }

      assert.same 1, PostReports\count!

      report\refresh!

      assert.same nil, report.body
      assert.same PostReports.reasons.spam, report.reason

    it "increments report count for category", ->
      r1 = factory.PostReports category_id: 1
      r2 = factory.PostReports category_id: 1

      r3 = factory.PostReports category_id: 2

      assert.same 1, r1.category_report_number
      assert.same 2, r2.category_report_number
      assert.same 1, r3.category_report_number

  describe "moderate_report", ->
    moderate_report = (params) ->
      ReportsFlow = require "community.flows.reports"
      in_request { post: params }, =>
        @current_user = current_user
        ReportsFlow(@)\moderate_report!

    it "fails with no params", ->
      assert.has_error(
        -> moderate_report {}
        { message: {"report_id: expected integer"} }
      )

    it "updates report", ->
      category = factory.Categories user_id: current_user.id
      report = factory.PostReports category_id: category.id

      action = moderate_report {
        report_id: report.id
        "report[status]": "resolved"
      }

      assert.same "update", action

      report\refresh!

      assert_report = types.assert types.partial {
        status: PostReports.statuses.resolved
        moderating_user_id: current_user.id
      }

      assert_report report

      assert_moderation_logs = types.assert types.shape {
        types.partial {
          category_id: category.id
          user_id: current_user.id
          object_id: report.id
          object_type: ModerationLogs.object_types.post_report
          action: "report.status(resolved)"
        }
      }

      assert_moderation_logs ModerationLogs\select!

    it "does not let unrelated user update report", ->
      report = factory.PostReports!

      assert.has_error(
        ->
          moderate_report {
            report_id: report.id
            "report[status]": "resolved"
          }

        { message: {"invalid report"}}
      )

      report\refresh!
      assert.same PostReports.statuses.pending, report.status

    it "purges report", ->
      category = factory.Categories user_id: current_user.id
      report = factory.PostReports category_id: category.id

      other_report = factory.PostReports!

      -- moderation log should also be removed
      factory.ModerationLogs {
        object: report
        action: "report.hello"
      }

      factory.ModerationLogs {
        object: other_report
        action: "report.hello"
      }

      action = moderate_report {
        report_id: report.id
        action: "purge"
        "report[status]": "resolved"
      }

      assert.same "purge", action

      assert.same 1, PostReports\count!
      assert.same 1, ModerationLogs\count!

      assert.same 1, PostReports\count "id = ?", other_report.id
      assert.same 1, ModerationLogs\count "object_id = ?", other_report.id


  describe "show_reports", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id

    show_reports = (user=current_user, params) ->
      CategoriesFlow = require "community.flows.categories"
      ReportsFlow = require "community.flows.reports"
      in_request { get: params }, =>
        @current_user = user
        CategoriesFlow(@)\load_category!
        ReportsFlow(@)\show_reports @category

        {
          page: @page
          reports: @reports
        }


    it "doesn't let unrelated user view reports", ->
      other_user = factory.Users!

      assert.has_error(
        ->
          show_reports other_user, {
            category_id: category.id
          }
        {
          message: {"invalid category"}
        }
      )

    it "shows empty reports", ->
      res = show_reports current_user, {
        category_id: category.id
      }

      assert.same {}, res.reports

    it "shows empty reports with status", ->
      res = show_reports current_user, {
        category_id: category.id
        status: "ignored"
      }

      assert.same {}, res.reports

    it "shows reports", ->
      report = factory.PostReports category_id: category.id
      other_report = factory.PostReports category_id: factory.Categories!.id

      res = show_reports current_user, {
        category_id: category.id
      }

      assert_reports = types.assert types.shape {
        types.partial {
          category_id: category.id
        }
      }

      assert_reports res.reports

      -- gets page 2
      res = show_reports current_user, {
        page: "2"
        category_id: category.id
      }
      assert.same {}, res.reports

