import in_request from require "spec.flow_helpers"

import Users from require "models"
import TestApp from require "spec.helpers"

factory = require "spec.factory"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

import types from require "tableshape"

class ReportingApp extends TestApp
  @before_filter =>
    @current_user = Users\find assert @params.current_user_id, "missing user id"
    ReportsFlow = require "community.flows.reports"
    @flow = ReportsFlow @

  "/report": capture_errors_json =>
    @flow\update_or_create_report!
    json: { success: true }

  "/moderate-report": capture_errors_json =>
    @flow\moderate_report!
    json: { success: true }

  "/show": capture_errors_json =>
    CategoriesFlow = require "community.flows.categories"
    CategoriesFlow(@)\load_category!
    @flow\show_reports @category

    json: {
      page: @page
      reports: @reports
      success: true
    }


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
    it "should fail with no params", ->
      res = ReportingApp\get current_user, "/moderate-report", {}
      assert.truthy res.errors

    it "should update report", ->
      category = factory.Categories user_id: current_user.id
      report = factory.PostReports category_id: category.id

      res = ReportingApp\get current_user, "/moderate-report", {
        report_id: report.id
        "report[status]": "resolved"
      }

      assert.truthy res.success
      report\refresh!
      assert.same PostReports.statuses.resolved, report.status
      assert.same current_user.id, report.moderating_user_id

      assert.same 1, ModerationLogs\count!

      log = unpack ModerationLogs\select!
      assert.same category.id, log.category_id
      assert.same current_user.id, log.user_id
      assert.same report.id, log.object_id
      assert.same ModerationLogs.object_types.post_report, log.object_type
      assert.same "report.status(resolved)", log.action

    it "should not let unrelated user update report", ->
      report = factory.PostReports!

      res = ReportingApp\get current_user, "/moderate-report", {
        report_id: report.id
        "report[status]": "resolved"
      }

      assert.truthy res.errors
      assert.falsy res.success

      report\refresh!
      assert.same PostReports.statuses.pending, report.status

  describe "show_reports", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id


    it "doesn't let unrelated user view reports", ->
      other_user = factory.Users!

      res = ReportingApp\get other_user, "/show", {
        category_id: category.id
      }

      assert.same {errors: {"invalid category"}}, res


    it "shows empty reports", ->
      res = ReportingApp\get current_user, "/show", {
        category_id: category.id
      }

      assert.same {}, res.reports

    it "shows reports with status", ->
      res = ReportingApp\get current_user, "/show", {
        category_id: category.id
        status: "ignored"
      }

      assert.same {}, res.reports

    it "shows reports", ->
      report = factory.PostReports category_id: category.id
      other_report = factory.PostReports category_id: factory.Categories!.id

      res = ReportingApp\get current_user, "/show", {
        category_id: category.id
      }

      for r in *res.reports
        assert.same category.id, r.category_id

      -- gets page 2
      res = ReportingApp\get current_user, "/show", {
        page: "2"
        category_id: category.id
      }
      assert.same {}, res.reports

