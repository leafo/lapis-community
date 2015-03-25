import use_test_env from require "lapis.spec"

import truncate_tables from require "lapis.spec.db"

import Users, Categories, Topics, Posts, PostReports from require "models"
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

  "/new-report": capture_errors_json =>
    @flow\new_report!
    json: { success: true }

  "/update-report": capture_errors_json =>
    @flow\update_report!
    json: { success: true }

describe "reports", ->
  use_test_env!

  local current_user

  before_each ->
    truncate_tables Users, Categories, Topics, Posts, PostReports
    current_user = factory.Users!

  describe "new_report", ->
    it "should fail to create report", ->
      res = ReportingApp\get current_user, "/new-report", {}
      assert.truthy res.errors

    it "should create a new report", ->
      post = factory.Posts!

      res = ReportingApp\get current_user, "/new-report", {
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

    it "should create new report for post in topic without category", ->
      topic = factory.Topics category: false
      post = factory.Posts topic_id: topic.id

      res = ReportingApp\get current_user, "/new-report", {
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

  describe "update_report", ->
    update_report = (get={}) ->
      get.current_user_id or= current_user.id
      status, res = mock_request ReportingApp, "/update-report", {
        :get
        expect: "json"
      }

      assert.same 200, status
      res

    it "should fail with no params", ->
      res = update_report!
      assert.truthy res.errors

    it "should update report", ->
      category = factory.Categories user_id: current_user.id
      report = factory.PostReports category_id: category.id

      res = update_report {
        report_id: report.id
        "report[status]": "resolved"
      }

      assert.truthy res.success
      report\refresh!
      assert.same PostReports.statuses.resolved, report.status


