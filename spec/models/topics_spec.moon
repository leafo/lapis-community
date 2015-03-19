env = require "lapis.environment"
import truncate_tables from require "lapis.spec.db"
import Users, Categories, Topics, Posts from require "models"

factory = require "spec.factory"

describe "topics", ->
  setup ->
    env.push "test"

  teardown ->
    env.pop!

  before_each ->
    truncate_tables Users, Categories, Topics, Posts

  it "should create a post", ->
    factory.Topics!


