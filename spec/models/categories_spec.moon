import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Categories, CategoryModerators, CategoryMembers from require "community.models"

factory = require "spec.factory"

describe "categories", ->
  use_test_env!

  before_each ->
    truncate_tables Users, Categories, CategoryModerators, CategoryMembers

  it "should create a category", ->
    factory.Categories!

  describe "with category", ->
    local category, category_user

    before_each ->
      category_user = factory.Users!
      category = factory.Categories user_id: category_user.id

    it "should check permissions for no user", ->
      assert.truthy category\allowed_to_view nil
      assert.falsy category\allowed_to_post nil

      assert.falsy category\allowed_to_edit nil
      assert.falsy category\allowed_to_edit_moderators nil
      assert.falsy category\allowed_to_edit_members nil
      assert.falsy category\allowed_to_moderate nil

    it "should check permissions for owner", ->
      assert.truthy category\allowed_to_view category_user
      assert.truthy category\allowed_to_post category_user

      assert.truthy category\allowed_to_edit category_user
      assert.truthy category\allowed_to_edit_moderators category_user
      assert.truthy category\allowed_to_edit_members category_user
      assert.truthy category\allowed_to_moderate category_user

    it "should check permissions for random user", ->
      other_user = factory.Users!

      assert.truthy category\allowed_to_view other_user
      assert.truthy category\allowed_to_post other_user

      assert.falsy category\allowed_to_edit other_user
      assert.falsy category\allowed_to_edit_moderators other_user
      assert.falsy category\allowed_to_edit_members other_user
      assert.falsy category\allowed_to_moderate other_user

    it "should check permissions for random user with members only", ->
      category\update membership_type: Categories.membership_types.members_only

      other_user = factory.Users!

      assert.falsy category\allowed_to_view other_user
      assert.falsy category\allowed_to_post other_user

      assert.falsy category\allowed_to_edit other_user
      assert.falsy category\allowed_to_edit_moderators other_user
      assert.falsy category\allowed_to_edit_members other_user
      assert.falsy category\allowed_to_moderate other_user

    it "should check category member with members only", ->
      category\update membership_type: Categories.membership_types.members_only
      member_user = factory.Users!
      factory.CategoryMembers user_id: member_user.id, category_id: category.id

      assert.truthy category\allowed_to_view member_user
      assert.truthy category\allowed_to_post member_user

      assert.falsy category\allowed_to_edit member_user
      assert.falsy category\allowed_to_edit_moderators member_user
      assert.falsy category\allowed_to_edit_members member_user
      assert.falsy category\allowed_to_moderate member_user

    it "should check moderation permissions", ->
      some_user = factory.Users!
      admin_user = with factory.Users!
        .is_admin = => true

      mod_user = factory.Users!
      some_mod_user = factory.Users!

      factory.CategoryModerators user_id: mod_user.id, category_id: category.id
      factory.CategoryModerators user_id: some_mod_user.id

      assert.falsy category\allowed_to_moderate nil
      assert.falsy category\allowed_to_moderate some_user
      assert.falsy category\allowed_to_moderate some_mod_user
      assert.truthy category\allowed_to_moderate category_user
      assert.truthy category\allowed_to_moderate admin_user
      assert.truthy category\allowed_to_moderate mod_user

