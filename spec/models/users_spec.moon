env = require "lapis.environment"
import truncate_tables from require "lapis.spec.db"
import Users, CommunityUsers from require "models"

factory = require "spec.factory"

describe "users", ->
  setup ->
    env.push "test"

  teardown ->
    env.pop!

  before_each ->
    truncate_tables Users, CommunityUsers

  it "should create a user", ->
    factory.Users!


