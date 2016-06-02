import use_test_env from require "lapis.spec"

factory = require "spec.factory"

describe "models.users", ->
  use_test_env!

  import Users from require "spec.models"
  import CommunityUsers from require "spec.community_models"

  it "should create a user", ->
    factory.Users!

  it "creates a community user", ->
    user = factory.Users!
    cu = CommunityUsers\for_user user.id
    assert.same user.id, cu.user_id


