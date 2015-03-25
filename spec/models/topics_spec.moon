import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"
import Users, Categories, CategoryModerators, Topics, Posts from require "models"

factory = require "spec.factory"

describe "topics", ->
  use_test_env!

  before_each ->
    truncate_tables Users, Categories, CategoryModerators, Topics, Posts

  it "should check permissions of topic with category", ->
    category_user = factory.Users!
    category = factory.Categories user_id: category_user.id

    topic = factory.Topics category_id: category.id
    user = topic\get_user!

    assert.truthy topic\allowed_to_post user
    assert.truthy topic\allowed_to_view user
    assert.truthy topic\allowed_to_edit user
    assert.falsy topic\allowed_to_moderate user

    other_user = factory.Users!

    assert.truthy topic\allowed_to_post other_user
    assert.truthy topic\allowed_to_view other_user
    assert.falsy topic\allowed_to_edit other_user
    assert.falsy topic\allowed_to_moderate other_user

    mod = factory.CategoryModerators category_id: topic.category_id
    mod_user = mod\get_user!

    assert.truthy topic\allowed_to_post mod_user
    assert.truthy topic\allowed_to_view mod_user
    assert.truthy topic\allowed_to_edit mod_user
    assert.truthy topic\allowed_to_moderate mod_user

    -- 

    assert.truthy topic\allowed_to_post category_user
    assert.truthy topic\allowed_to_view category_user
    assert.truthy topic\allowed_to_edit category_user
    assert.truthy topic\allowed_to_moderate category_user


  it "should check permissions of topic without category", ->
    topic = factory.Topics category: false

    user = topic\get_user!

    assert.truthy topic\allowed_to_post user
    assert.truthy topic\allowed_to_view user
    assert.truthy topic\allowed_to_edit user
    assert.falsy topic\allowed_to_moderate user

    other_user = factory.Users!

    assert.truthy topic\allowed_to_post other_user
    assert.truthy topic\allowed_to_view other_user
    assert.falsy topic\allowed_to_edit other_user
    assert.falsy topic\allowed_to_moderate other_user


