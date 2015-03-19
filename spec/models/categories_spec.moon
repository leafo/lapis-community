import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"
import Users, Categories, CategoryModerators from require "models"

factory = require "spec.factory"

describe "categories", ->
  use_test_env!

  before_each ->
    truncate_tables Categories, Users

  it "should create a category", ->
    factory.Categories!

  describe "moderators", ->
    before_each ->
      truncate_tables Users, CategoryModerators

    it "allowed_to_moderate", ->
      owner = factory.Users!
      some_user = factory.Users!
      admin_user = with factory.Users!
        .is_admin = => true

      mod_user = factory.Users!
      some_mod_user = factory.Users!

      category = factory.Categories user_id: owner.id
      factory.CategoryModerators user_id: mod_user.id, category_id: category.id
      factory.CategoryModerators user_id: some_mod_user.id

      assert.falsy category\allowed_to_moderate nil
      assert.falsy category\allowed_to_moderate some_user
      assert.falsy category\allowed_to_moderate some_mod_user
      assert.truthy category\allowed_to_moderate owner
      assert.truthy category\allowed_to_moderate admin_user
      assert.truthy category\allowed_to_moderate mod_user


