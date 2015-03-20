import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"
import Users, Categories, Topics, Posts from require "models"

factory = require "spec.factory"

describe "topics", ->
  use_test_env!

  before_each ->
    truncate_tables Users, Categories, Topics, Posts

  it "should create a post", ->
    factory.Topics!

