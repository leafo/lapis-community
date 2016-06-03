import use_test_env from require "lapis.spec"

import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import TestApp from require "spec.helpers"

factory = require "spec.factory"

import mock_request from require "lapis.spec.request"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

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
  use_test_env!

  local current_user

  import Users from require "spec.models"
  import Categories, Topics, Posts, PostReports, ModerationLogs from require "spec.community_models"

  before_each ->
    current_user = factory.Users!

  describe "report", ->
    it "should fail to create report", ->
      res = ReportingApp\get current_user, "/report", {}
      assert.truthy res.errors

    it "should not report be created for own post", ->
      post = factory.Posts user_id: current_user.id

      res = ReportingApp\get current_user, "/report", {
        post_id: post.id
        "report[reason]": "other"
        "report[body]": "this is the problem"
      }

      assert.truthy res.errors
      assert.same 0, PostReports\count!

    it "should create a new report", ->
      post = factory.Posts!

      res = ReportingApp\get current_user, "/report", {
        post_id: post.id
        "report[reason]": "other"
        "report[body]": "this is the problem"
      }

      assert.same {success: true}, res
      reports = PostReports\select!
      assert.same 1, #reports

      topic = post\get_topic!
      report = unpack reports
      assert.same topic.category_id, report.category_id
      assert.same post.id, report.post_id
      assert.same current_user.id, report.user_id
      assert.same PostReports.statuses.pending, report.status
      assert.same PostReports.reasons.other, report.reason
      assert.same "this is the problem", report.body

    it "creates new report without body", ->
      post = factory.Posts!

      res = ReportingApp\get current_user, "/report", {
        post_id: post.id
        "report[reason]": "other"
      }

      assert.falsy res.errors

    it "should create new report for post in topic without category", ->
      topic = factory.Topics category: false
      post = factory.Posts topic_id: topic.id

      res = ReportingApp\get current_user, "/report", {
        post_id: post.id
        "report[reason]": "other"
        "report[body]": "please report"
      }

      assert.truthy res.success

      reports = PostReports\select!
      assert.same 1, #reports

      report = unpack reports
      assert.same nil, report.category_id
      assert.same post.id, report.post_id

    it "should update existing report", ->
      report = factory.PostReports user_id: current_user.id

      res = ReportingApp\get current_user, "/report", {
        post_id: report.post_id
        "report[reason]": "spam"
        "report[body]": "I am updating my report"
      }

      assert.falsy res.errors
      assert.truthy res.success

      assert.same 1, PostReports\count!
      report\refresh!

      assert.same "I am updating my report", report.body
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

