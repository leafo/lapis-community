import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

describe "community.helpers.counters", ->
  use_test_env!

  it "should", ->
    import bulk_increment from require "community.helpers.counters"
    import Users from require "models"
    print bulk_increment Users, "something_count", {{1,2}, {3,4}}

