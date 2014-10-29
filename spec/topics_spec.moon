import load_test_server, close_test_server, request from require "lapis.spec.server"
import truncate_tables from require "lapis.spec.db"
import Users, Categories, Topics, Posts from require "models"

factory = require "spec.factory"

describe "topics", ->
  setup ->
    load_test_server!

  teardown ->
    close_test_server!

  before_each ->
    truncate_tables Users, Categories, Topics, Posts

  it "should create a post", ->
    factory.Topics!


