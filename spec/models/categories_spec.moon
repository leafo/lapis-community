import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Categories, Moderators, CategoryMembers, Bans, CategoryGroups, CategoryGroupCategories, UserCategoryLastSeens from require "community.models"

factory = require "spec.factory"

describe "models.categories", ->
  use_test_env!

  before_each ->
    truncate_tables Users, Categories, Moderators, CategoryMembers, Bans,
      CategoryGroups, CategoryGroupCategories, UserCategoryLastSeens

  it "should create a category", ->
    factory.Categories!

  describe "with category", ->
    local category, category_user

    before_each ->
      category_user = factory.Users!
      category = factory.Categories user_id: category_user.id

    it "should check permissions for no user", ->
      assert.truthy category\allowed_to_view nil
      assert.falsy category\allowed_to_post_topic nil

      assert.falsy category\allowed_to_edit nil
      assert.falsy category\allowed_to_edit_moderators nil
      assert.falsy category\allowed_to_edit_members nil
      assert.falsy category\allowed_to_moderate nil

    it "should check permissions for owner", ->
      assert.truthy category\allowed_to_view category_user
      assert.truthy category\allowed_to_post_topic category_user

      assert.truthy category\allowed_to_edit category_user
      assert.truthy category\allowed_to_edit_moderators category_user
      assert.truthy category\allowed_to_edit_members category_user
      assert.truthy category\allowed_to_moderate category_user

    it "should check permissions for random user", ->
      other_user = factory.Users!

      assert.truthy category\allowed_to_view other_user
      assert.truthy category\allowed_to_post_topic other_user

      assert.falsy category\allowed_to_edit other_user
      assert.falsy category\allowed_to_edit_moderators other_user
      assert.falsy category\allowed_to_edit_members other_user
      assert.falsy category\allowed_to_moderate other_user

    it "should check permissions for random user with members only", ->
      category\update membership_type: Categories.membership_types.members_only

      other_user = factory.Users!

      assert.falsy category\allowed_to_view other_user
      assert.falsy category\allowed_to_post_topic other_user

      assert.falsy category\allowed_to_edit other_user
      assert.falsy category\allowed_to_edit_moderators other_user
      assert.falsy category\allowed_to_edit_members other_user
      assert.falsy category\allowed_to_moderate other_user

    it "should check category member with members only", ->
      category\update membership_type: Categories.membership_types.members_only
      member_user = factory.Users!
      factory.CategoryMembers user_id: member_user.id, category_id: category.id

      assert.truthy category\allowed_to_view member_user
      assert.truthy category\allowed_to_post_topic member_user

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

      factory.Moderators user_id: mod_user.id, object: category
      factory.Moderators user_id: some_mod_user.id

      assert.falsy category\allowed_to_moderate nil
      assert.falsy category\allowed_to_moderate some_user
      assert.falsy category\allowed_to_moderate some_mod_user
      assert.truthy category\allowed_to_moderate category_user
      assert.truthy category\allowed_to_moderate admin_user
      assert.truthy category\allowed_to_moderate mod_user

    it "should check moderation permissions for category in group", ->
      group = factory.CategoryGroups!
      group\add_category category

      mod_user = factory.Users!
      factory.Moderators user_id: mod_user.id, object: group

      assert.falsy category\allowed_to_edit mod_user
      assert.falsy category\allowed_to_edit_moderators mod_user
      assert.true category\allowed_to_moderate mod_user

    it "should check permissions for banned user", ->
      banned_user = factory.Users!

      assert.falsy category\find_ban banned_user
      factory.Bans object: category, banned_user_id: banned_user.id
      assert.truthy category\find_ban banned_user

      assert.falsy category\allowed_to_view banned_user
      assert.falsy category\allowed_to_post_topic banned_user

      assert.falsy category\allowed_to_edit banned_user
      assert.falsy category\allowed_to_edit_moderators banned_user
      assert.falsy category\allowed_to_edit_members banned_user
      assert.falsy category\allowed_to_moderate banned_user

      group_banned_user = factory.Users!
      group = factory.CategoryGroups!
      group\add_category category
      factory.Bans object: group, banned_user_id: group_banned_user.id

      assert.falsy category\allowed_to_view group_banned_user
      assert.falsy category\allowed_to_post_topic group_banned_user

    it "should update last topic to nothing", ->
      category\refresh_last_topic!
      assert.falsy category.last_topic_id

    it "should update last topic with a topic", ->
      topic = factory.Topics category_id: category.id
      factory.Topics category_id: category.id, deleted: true

      category\refresh_last_topic!

      assert.same category.last_topic_id, topic.id

    it "should refresh last topic ignoring spam", ->
      t1 = factory.Topics category_id: category.id
      t2 = factory.Topics category_id: category.id, status: "spam"

      category\refresh_last_topic!
      assert.same category.last_topic_id, t1.id

    it "gets voting type", ->
      assert.same Categories.voting_types.up_down, category\get_voting_type!

    it "gets membership_type type", ->
      assert.same Categories.membership_types.public, category\get_membership_type!

    describe "last seen #ddd", ->
      it "does nothing for category with no last topic", ->
        current_user = factory.Users!
        category\set_seen current_user
        assert.same 0, UserCategoryLastSeens\count!

      it "sets last seen for category with topic", ->
        current_user = factory.Users!

        t1 = factory.Topics category_id: category.id
        category\increment_from_topic t1

        category\set_seen current_user
        assert.same 1, UserCategoryLastSeens\count!

        -- noop
        category\set_seen current_user
        last_seen = assert category\find_last_seen_for_user current_user

        do
          l = unpack UserCategoryLastSeens\select!
          assert.false l\should_update!

        assert.same current_user.id, last_seen.user_id
        assert.same t1.category_order, last_seen.category_order
        assert.same t1.id, last_seen.topic_id
        assert.same category.id, last_seen.category_id

        t2 = factory.Topics category_id: category.id
        category\increment_from_topic t2

        do
          l = unpack UserCategoryLastSeens\select!
          assert.true l\should_update!

        category\set_seen current_user

        assert.same 1, UserCategoryLastSeens\count!

        last_seen = assert category\find_last_seen_for_user current_user

        assert.same current_user.id, last_seen.user_id
        assert.same t2.id, last_seen.topic_id
        assert.same t2.category_order, last_seen.category_order
        assert.same category.id, last_seen.category_id

      it "detects unread", ->
        current_user = factory.Users!

        assert.falsy category\has_unread nil
        assert.falsy category\has_unread current_user

        t1 = factory.Topics category_id: category.id
        category\increment_from_topic t1

        -- this is nil
        last_seen = category\find_last_seen_for_user current_user
        assert not last_seen, "expected no last_seen"

        -- never seen category before, so nothing is unread
        assert.falsy category\has_unread current_user

        category\set_seen current_user
        last_seen = category\find_last_seen_for_user current_user
        assert last_seen, "expected last_seen"
        category.user_category_last_seen = last_seen

        -- user's last seen is up to date
        assert.falsy category\has_unread current_user

        t2 = factory.Topics category_id: category.id
        category\increment_from_topic t2

        -- user's last seen is out of date
        assert.truthy category\has_unread current_user

    describe "ancestors", ->
      it "gets ancestors with no ancestors", ->
        assert.same {}, category\get_ancestors!

      describe "with hierarchy", ->
        -- (child) deep -> mid -> category (parent)
        local mid, deep
        before_each ->
          mid = factory.Categories parent_category_id: category.id
          deep = factory.Categories parent_category_id: mid.id

        it "gets ancestors with ancestors", ->
          assert.same {mid.id, category.id}, [c.id for c in *deep\get_ancestors!]

        it "searches ancestors for moderators", ->
          user = factory.Users!
          mod = deep\find_moderator user, accepted: true, admin: true
          assert.same nil, mod

          mod = factory.Moderators {
            object: mid
            user_id: user.id
            accepted: true
            admin: true
          }

          found_mod = deep\find_moderator user, accepted: true, admin: true
          assert.same mod.id, found_mod.id

        it "searches ancestors for bans", ->
          user = factory.Users!
          assert.same nil, (deep\find_ban user)

          ban = factory.Bans {
            object: mid
            banned_user_id: user.id
          }

          found = deep\find_ban user
          assert.same {ban.object_type, ban.object_id},
            {found.object_type, found.object_id}

        it "searches ancestors for members", ->
          user = factory.Users!
          assert.same nil, (deep\find_member user)

          member = factory.CategoryMembers {
            category_id: category.id
            user_id: user.id
            accepted: true
          }

          found = deep\find_member user, accepted: true
          assert.same found.user_id, user.id

        it "gets default voting type", ->
          assert.same Categories.voting_types.up_down, category\get_voting_type!

        it "gets default membership_type type", ->
          assert.same Categories.membership_types.public, category\get_membership_type!

        it "gets ancestor voting type", ->
          category\update voting_type: Categories.voting_types.disabled
          mid\update voting_type: Categories.voting_types.up
          assert.same Categories.voting_types.up, deep\get_voting_type!

        it "gets ancestor membership type", ->
          category\update membership_type: Categories.membership_types.public
          mid\update membership_type: Categories.membership_types.members_only
          assert.same Categories.membership_types.members_only, deep\get_membership_type!

    describe "children", ->
      flatten_children = (cs, fields={"id"}) ->
        return for c in *cs
          o = {f, c[f] for f in *fields}
          o.children = if c.children
            flatten_children c.children, fields
          o

      it "gets empty children", ->
        assert.same {}, category\get_children!

      it "gets hierarchy", ->
        other_cat = factory.Categories!

        a = factory.Categories parent_category_id: category.id
        b = factory.Categories parent_category_id: category.id
        a2 = factory.Categories parent_category_id: a.id

        -- other categories should not interfere
        xx = factory.Categories parent_category_id: other_cat.id
        factory.Categories parent_category_id: xx.id

        children = category\get_children!
        assert.same children, category.children

        assert.same {
          {
            id: a.id
            children: {
              { id: a2.id}
            }
          }
          {
            id: b.id
          }
        }, flatten_children children

      it "gets hierarchy with many children", ->
        a = factory.Categories parent_category_id: category.id, title: "hi"
        a1 = factory.Categories parent_category_id: a.id, title: "alpha"
        a2 = factory.Categories parent_category_id: a.id, title: "beta"
        a3 = factory.Categories parent_category_id: a.id, title: "gama"

        assert.same {
          {
            title: "hi"
            children: {
              { title: "alpha" }
              { title: "beta" }
              { title: "gama" }
            }
          }

        }, flatten_children category\get_children!, {"title"}

    describe "get_order_ranges", ->
      it "gets empty order range", ->
        assert.same {regular: {}, sticky: {}}, category\get_order_ranges!

      it "gets order range with one topic", ->
        topic = factory.Topics category_id: category.id
        assert.same {
          regular: {min: 1, max: 1}
          sticky: {}
        }, category\get_order_ranges!

      it "gets order range with a few topics", ->
        topic = factory.Topics category_id: category.id

        for i=1,3
          factory.Topics category_id: category.id

        topic\increment_from_post factory.Posts topic_id: topic.id

        assert.same {
          regular: {min: 2, max: 5}
          sticky: {}
        }, category\get_order_ranges!

      it "gets order range with deleted topics", ->
        topic = factory.Topics category_id: category.id
        factory.Topics category_id: category.id
        topic\delete!

        assert.same {
          regular: {min: 2, max: 2}
          sticky: {}
        }, category\get_order_ranges!

      it "gets order range with archived topics", ->
        topics = for i=1,4
          with topic = factory.Topics category_id: category.id
            category\increment_from_topic topic

        topics[1]\archive!

        assert.same {
          regular: {min: 2, max: 4}
          sticky: {}
        }, category\get_order_ranges!

        assert.same {
          regular: {min: 1, max: 1}
          sticky: {}
        }, category\get_order_ranges "archived"

  describe "position", ->
    it "creates hierarchy with position set correctly", ->
      root = factory.Categories!
      root2 = factory.Categories!

      a = factory.Categories parent_category_id: root.id
      assert.same 1, a.position

      a2 = factory.Categories parent_category_id: root2.id
      assert.same 1, a2.position

      b = factory.Categories parent_category_id: root.id
      assert.same 2, b.position
