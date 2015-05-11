import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Categories, CategoryModerators, CategoryMembers, Topics, Posts, Bans from require "community.models"

factory = require "spec.factory"

describe "topics", ->
  use_test_env!

  before_each ->
    truncate_tables Users, Categories, CategoryModerators, CategoryMembers, Topics, Posts, Bans

  it "should create a topic", ->
    factory.Topics!
    factory.Topics category: false

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


  it "should check permissions of topic with members only category", ->
    category_user = factory.Users!
    category = factory.Categories {
      user_id: category_user.id
      membership_type: Categories.membership_types.members_only
    }

    topic = factory.Topics category_id: category.id

    other_user = factory.Users!
    assert.falsy topic\allowed_to_view other_user
    assert.falsy topic\allowed_to_post other_user

    member_user = factory.Users!
    factory.CategoryMembers user_id: member_user.id, category_id: category.id

    assert.truthy topic\allowed_to_view member_user
    assert.truthy topic\allowed_to_post member_user

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

  it "should set category order", ->
    one = factory.Topics category_id: 123
    two = factory.Topics category_id: 123
    three = factory.Topics category_id: 123

    assert.same 1, one.category_order
    assert.same 2, two.category_order
    assert.same 3, three.category_order

    post = factory.Posts topic_id: one.id
    one\increment_from_post post
    assert.same 4, one.category_order

    four = factory.Topics category_id: 123
    assert.same 5, four.category_order

  it "should check permission for banned user", ->
    topic = factory.Topics!
    banned_user = factory.Users!

    assert.falsy topic\find_ban banned_user
    factory.Bans object: topic, banned_user_id: banned_user.id
    assert.truthy topic\find_ban banned_user

    assert.falsy topic\allowed_to_view banned_user
    assert.falsy topic\allowed_to_post banned_user

  it "should refresh last post id", ->
    topic = factory.Topics!
    post = factory.Posts topic_id: topic.id
    factory.Posts topic_id: topic.id, deleted: true

    topic\refresh_last_post!

    assert.same post.id, topic.last_post_id

