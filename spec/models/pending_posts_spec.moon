import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import PendingPosts, Categories, Topics, Posts from require "community.models"

db = require "lapis.db"

factory = require "spec.factory"

describe "posts", ->
  use_test_env!

  before_each ->
    truncate_tables Users, PendingPosts, Categories, Toics, Posts

  it "creates a pending post", ->
    factory.PendingPosts!

