import
  load_test_server
  close_test_server
  request
  from require "lapis.spec.server"

import truncate_tables from require "lapis.spec.db"

import Users, Categories, Topics, Posts, PostReports from require "models"

factory = require "spec.factory"

import mock_request from require "lapis.spec.request"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

class ReportingApp extends Application
  @before_filter =>
    @current_user = Users\find assert @params.current_user_id, "missing user id"
    ReportsFlow = require "community.flows.reports"
    @flow = ReportsFlow @

  "/new-report": capture_errors_json =>
    @flow\new_report!
    json: { success: true }

describe "reports", ->
  local current_user

  setup ->
    load_test_server!

  teardown ->
    close_test_server!

  before_each ->
    truncate_tables Users, Categories, Topics, Posts, PostReports
    current_user = factory.Users!

  describe "new_report", ->
    new_report = (get={}) ->
      get.current_user_id or= current_user.id
      status, res = mock_request ReportingApp, "/new-report", {
        :get
        expect: "json"
      }

      assert.same 200, status
      res

    it "should fail to create report", ->
      res = new_report!
      assert.truthy {}, res.errors

