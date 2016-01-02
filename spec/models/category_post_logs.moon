import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Categories, Topics, Posts, CategoryPostLogs from require "community.models"

factory = require "spec.factory"

describe "models.category_tags", ->
  use_test_env!

  before_each ->
    truncate_tables Categories, Topics, Posts, CategoryPostLogs

