import
  load_test_server
  close_test_server
  request
  from require "lapis.spec.server"

import truncate_tables from require "lapis.spec.db"

factory = require "spec.factory"

import mock_request from require "lapis.spec.request"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

class PostingApp extends Application
  @before_filter =>
    @current_user = Users\find assert @params.current_user_id, "missing user id"
    CategoriesFlow = require "community.flows.categories"
    @flow = CategoriesFlow @

  "/add-member": =>
    @flow\add_member!
    json: true

  "/remove-member": =>
    @flow\remove_member!

  "/approve-member": =>
    @flow\approve_member!
    json: true

describe "category_membership", ->
  setup ->
    load_test_server!

  teardown ->
    close_test_server!

  before_each ->

  describe "add member", ->

