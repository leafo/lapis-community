db = require "lapis.db"
factory = require "spec.factory"

import assert_no_queries from require "spec.helpers"

describe "models.categories", ->
  import Users from require "spec.models"
  import Categories, Moderators, CategoryMembers, Bans,
    CategoryGroups, CategoryGroupCategories, UserCategoryLastSeens, Topics
    from require "spec.community_models"

  it "should create a category", ->
    factory.Categories!

  describe "recount", ->
    it "recounts all categoriers", ->
      factory.Categories!
      Categories\recount!

    it "recounts specific categoriers", ->
      cat = factory.Categories!
      cat2 = factory.Categories!

      Categories\recount id: cat.id
      Categories\recount "id in ?", db.list { cat.id, cat2.id }

  describe "tags", ->
    import CategoryTags from require "spec.community_models"

    it "should parse tags", ->
      category = factory.Categories!
      factory.CategoryTags slug: "hello", category_id: category.id
      factory.CategoryTags slug: "world", category_id: category.id

      assert.same {
        "hello"
      }, [t.slug for t in *category\parse_tags "hello,zone,hello,butt"]

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
      category\refresh! -- clear loaded relations


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

    describe "last seen", ->
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
        category\refresh!

        assert.same 1, UserCategoryLastSeens\count!

        last_seen = assert category\find_last_seen_for_user current_user

        assert.same current_user.id, last_seen.user_id
        assert.same t2.id, last_seen.topic_id
        assert.same t2.category_order, last_seen.category_order
        assert.same category.id, last_seen.category_id

      it "detects unread", ->
        current_user = factory.Users!

        assert.falsy (category\has_unread nil)
        assert.falsy (category\has_unread current_user)

        t1 = factory.Topics category_id: category.id
        category\increment_from_topic t1

        -- this is nil
        last_seen = category\find_last_seen_for_user current_user
        assert.nil last_seen, "expected no last_seen"

        -- never seen category before, so nothing is unread
        assert.falsy (category\has_unread current_user)

        category\set_seen current_user
        category\refresh!

        last_seen = category\find_last_seen_for_user current_user
        assert last_seen, "expected last_seen"
        category.user_category_last_seen = last_seen

        -- user's last seen is up to date
        assert.falsy (category\has_unread current_user)

        t2 = factory.Topics category_id: category.id
        category\increment_from_topic t2

        -- user's last seen is out of date
        assert.truthy category\has_unread current_user

    describe "ancestors", ->
      it "gets ancestors with no ancestors", ->
        assert.same {}, category\get_ancestors!

      it "preloads single with no ancestors", ->
        Categories\preload_ancestors { category }
        assert.same {}, category\get_ancestors!

      describe "with hierarchy", ->
        -- (child) deep -> mid -> category (parent)
        local mid, deep
        before_each ->
          mid = factory.Categories parent_category_id: category.id
          deep = factory.Categories parent_category_id: mid.id

        it "gets ancestors with ancestors", ->
          assert.same {mid.id, category.id}, [c.id for c in *deep\get_ancestors!]

        it "assembles category hierarchy without any queries", ->
          Categories\preload_ancestors { deep, mid, category }
          assert.same {mid.id, category.id}, [c.id for c in *deep.ancestors]
          assert.same {category.id}, [c.id for c in *mid.ancestors]
          assert.same {}, [c.id for c in *category.ancestors or {}]

        it "preloads from deepest, filling ancestors", ->
          Categories\preload_ancestors { deep }
          assert.same {mid.id, category.id}, [c.id for c in *deep.ancestors]
          assert.same {category.id}, [c.id for c in *deep.ancestors[1].ancestors]
          assert.same {}, [c.id for c in *deep.ancestors[2].ancestors or {}]

        it "preloads many adjacent", ->
          deep2 = factory.Categories parent_category_id: mid.id
          deep3 = factory.Categories parent_category_id: mid.id
          Categories\preload_ancestors { deep, deep2, deep3 }
          assert.same {mid.id, category.id}, [c.id for c in *deep.ancestors]
          assert.same {mid.id, category.id}, [c.id for c in *deep2.ancestors]
          assert.same {mid.id, category.id}, [c.id for c in *deep3.ancestors]

        it "searches ancestors for moderators", ->
          user = factory.Users!
          mod = deep\find_moderator user, accepted: true, admin: true
          assert.same nil, mod

          deep\refresh!

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

          deep\refresh!

          found = deep\find_ban user
          assert.same {ban.object_type, ban.object_id},
            {found.object_type, found.object_id}


        it "searches ancestors for members", ->
          user = factory.Users!
          other_user = factory.Users!

          assert.same nil, (deep\find_member user)

          s = (m) -> {m.user_id, m.category_id}

          member = factory.CategoryMembers {
            category_id: category.id
            user_id: user.id
            accepted: true
          }

          -- random other records
          factory.CategoryMembers {
            category_id: category.id
            user_id: other_user.id
            accepted: false
          }

          deep\refresh!

          do
            found = deep\find_member user, accepted: true
            assert.same s(member), s(found)

          do
            found = deep\find_member user, accepted: false
            assert.nil found

          do
            found = deep\find_member user
            assert.same s(member), s(found)

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

  describe "bans", ->
    relations = require "lapis.db.model.relations"

    local parent_category
    local categories

    before_each ->
      parent_category = factory.Categories!
      categories = for i=1,3
        factory.Categories {
          parent_category_id: i == 2 and parent_category.id or nil
        }

    it "preloads bans on many topics when user is not banned", ->
      user = factory.Users!
      Categories\preload_bans categories, user

      assert_no_queries ->
        for c in *categories
          c\with_user(user.id)\get_ban!
          assert.same {ban: true}, c\with_user(user.id)[relations.LOADED_KEY]

    it "preloads bans user", ->
      other_user = factory.Users!
      user = factory.Users!

      b1 = factory.Bans object: categories[2], banned_user_id: other_user.id

      b2 = factory.Bans object: categories[3], banned_user_id: user.id
      b3 = factory.Bans object: parent_category, banned_user_id: user.id

      Categories\preload_bans categories, user


      assert_no_queries ->
        for c in *categories
          assert.same { ban: true }, c\with_user(user.id)[relations.LOADED_KEY]
          c\with_user(user.id)\get_ban!

          for parent in *c\get_ancestors!
            assert.same { ban: true }, parent\with_user(user.id)[relations.LOADED_KEY]
            parent\with_user(user.id)\get_ban!


        assert.same nil, categories[1]\with_user(user.id).ban
        assert.same nil, categories[2]\with_user(user.id).ban
        assert.same b2, categories[3]\with_user(user.id).ban

        assert.same b3, categories[2]\get_parent_category!\with_user(user.id).ban

  describe "subscriptions", ->
    import Subscriptions from require "spec.community_models"

    local category

    before_each ->
      category = factory.Categories {
        user_id: factory.Users!.id
      }

    it "gets subscriptions", ->
      user = factory.Users!
      other_user = factory.Users!

      assert.same {}, category\get_subscriptions!
      category\refresh!
      Subscriptions\create {
        object_type: Subscriptions.object_types.category
        object_id: category.id
        user_id: user.id
      }

      assert.same 1, #category\get_subscriptions!

      assert.true category\is_subscribed user
      assert.false category\is_subscribed other_user


    it "subscribes user to topic", ->
      user = factory.Users!
      category\subscribe user
      s = unpack Subscriptions\select "", fields: "user_id, object_type, object_id, subscribed"

      assert.same {
        user_id: user.id
        object_id: category.id
        object_type: Subscriptions.object_types.category
        subscribed: true
      }, s

    it "unsubscribes user from topic", ->
      user = factory.Users!

      Subscriptions\create {
        object_type: Subscriptions.object_types.category
        object_id: category.id
        user_id: user.id
      }

      category\unsubscribe user
      assert.same {}, category\get_subscriptions!

    it "gets notification targets when there are no subscribers", ->
      users = category\notification_target_users!
      users = {u.id, true for u in *users}

      assert.same {
        [category.user_id]: true
      }, users

    it "gets notification targets when there are subscriptions in hierarchy", ->
      category_owner = category\get_user!
      one_owner = factory.Users!
      two_owner = factory.Users!

      one = factory.Categories {
        title: "one"
        parent_category_id: category.id
        user_id: one_owner.id
      }

      two = factory.Categories {
        title: "two"
        parent_category_id: one.id
        user_id: two_owner.id
      }

      user1 = factory.Users!
      user2 = factory.Users!

      -- one_owner not subscribes
      category\subscribe one_owner
      one\unsubscribe one_owner

      two\subscribe user1
      one\subscribe user2

      -- two onwner not subscribed
      two\unsubscribe two_owner
      category\subscribe two_owner

      users = two\notification_target_users!
      users = {u.id, true for u in *users}

      assert.same {
        [category_owner.id]: true
        [user1.id]: true
        [user2.id]: true
      }, users

  describe "refresh_topic_category_order", ->
    local category

    before_each ->
      category = factory.Categories!

    it "refreshes category order by post date", ->
      -- create some topics in reverse chronological order to be fixed
      topics = for i=1,3
        topic = factory.Topics {
          category_id: category.id
          created_at: db.raw "now() at time zone 'utc' - '#{i} day'::interval"
        }
        category\increment_from_topic topic
        topic

      assert.same topics[3].id,  category\get_last_topic!.id

      category\refresh_topic_category_order!
      category\refresh!

      assert.same topics[1].id, category\get_last_topic!.id

    it "refreshes category order by topic score", ->
      category\update category_order_type: assert Categories.category_order_types.topic_score

      topics = for i=1,3
        topic = factory.Topics {
          category_id: category.id
        }

        post = factory.Posts {
          topic_id: topic.id
          up_votes_count: 10 * (3 - i)
        }

        category\increment_from_topic topic
        topic\increment_from_post post
        topic

      category\refresh_topic_category_order!
      category\refresh!

      assert.same {
        topics[1].id
        topics[2].id
        topics[3].id
      }, [topic.id for topic in *Topics\select "order by category_order desc"]

      -- it has the same value as the one calculated in lua
      for topic in *topics
        topic\refresh!
        assert 1 >= math.abs topic.category_order - topic\calculate_score_category_order!

  describe "update_category_order_type", ->
    local category, topics

    before_each ->
      category = factory.Categories!

      topics = for i=1,4
        topic = factory.Topics {
          category_id: category.id
          created_at: db.raw db.interpolate_query "
            now() at time zone 'utc' - ?::interval
          ", "#{i} days"
        }

        post = factory.Posts {
          topic_id: topic.id
          up_votes_count: i
          -- posts are dated in ascending order to ensure they are sorted in
          -- the order they are created when sorting the topic
          created_at: "2022-1-#{i} 00:00:00"
        }

        category\increment_from_topic topic
        topic\increment_from_post post
        topic

    it "updates to score order and back", ->
      category\update_category_order_type "topic_score"
      category\update_category_order_type "post_date"

      for t in *topics
        t\refresh!

      order = [t.category_order for t in *topics]
      assert.same { 1,2,3,4 }, order

  describe "find_moderator", ->
    local categories, other_category
    before_each ->
      other_category = factory.Categories!
      categories = { factory.Categories! }
      -- created nested set
      for i=1,2
        table.insert categories, factory.Categories parent_category_id: categories[#categories].id

    it "finds no moderator", ->
      -- quickly confirm ancestor chain
      assert.same {categories[2].id, categories[1].id, categories[3].id}, categories[3]\get_category_ids!

      user = factory.Users!
      other_user = factory.Users!

      -- create some moderator objects we should ignore
      Moderators\create {
        object_type: "category"
        object_id: other_category.id
        user_id: user.id
        accepted: true
        admin: true
      }

      Moderators\create {
        object_type: "category"
        object_id: categories[2].id
        user_id: other_user.id
        accepted: true
        admin: true
      }


      assert.nil categories[1]\find_moderator(user), "expecting no moderator"
      assert.nil categories[2]\find_moderator(user), "expecting no moderator"
      assert.nil categories[3]\find_moderator(user), "expecting no moderator"

    -- the moderator object nearest to category requested should be returned
    it "finds moderator with precedence", ->
      user = factory.Users!

      m1 = Moderators\create {
        object_type: "category"
        object_id: categories[1].id
        user_id: user.id
        accepted: true
        admin: true
      }

      m2 = Moderators\create {
        object_type: "category"
        object_id: categories[2].id
        user_id: user.id
        accepted: true
        admin: true
      }

      do
        found_mod = categories[3]\find_moderator(user)
        assert.same m2\_primary_cond!, found_mod\_primary_cond!

      do
        found_mod = categories[2]\find_moderator(user)
        assert.same m2\_primary_cond!, found_mod\_primary_cond!

      do
        found_mod = categories[1]\find_moderator(user)
        assert.same m1\_primary_cond!, found_mod\_primary_cond!


    it "finds moderator with filtering", ->
      user = factory.Users!

      s = (m) -> {m.object_type, m.object_id, m.user_id}

      m1 = Moderators\create {
        object_type: "category"
        object_id: categories[1].id
        user_id: user.id
        accepted: true
        admin: true
      }

      m2 = Moderators\create {
        object_type: "category"
        object_id: categories[2].id
        user_id: user.id
        accepted: true
        admin: false
      }

      m3 = Moderators\create {
        object_type: "category"
        object_id: categories[3].id
        user_id: user.id
        accepted: false
        admin: false
      }

      deep = categories[3]

      do
        found_mod = deep\find_moderator user, accepted: true
        assert.same s(m2), s(found_mod)

      do
        found_mod = deep\find_moderator user, accepted: true, admin:false
        assert.same s(m2), s(found_mod)

      do
        found_mod = deep\find_moderator user, accepted: false
        assert.same s(m3), s(found_mod)

      do
        found_mod = deep\find_moderator user, admin: true, accepted: true
        assert.same s(m1), s(found_mod)

      do
        found_mod = deep\find_moderator user, accepted: false, admin: true
        assert.nil found_mod


