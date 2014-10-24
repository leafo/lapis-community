
import load_test_server, close_test_server, request from require "lapis.spec.server"
import truncate_tables from require "lapis.spec.db"
import Categories from require "models"

describe "categories", ->
  setup ->
    load_test_server!

  teardown ->
    close_test_server!

  before_each ->
    truncate_tables Categories

  it "should create a category", ->
    assert Categories\create {
      name: "hello world"
    }


