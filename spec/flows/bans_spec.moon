import in_request from require "spec.flow_helpers"

factory = require "spec.factory"

describe "bans", ->
  import Users from require "spec.models"
  import Bans, Categories, ModerationLogs,
    ModerationLogObjects, CategoryGroups from require "spec.community_models"

  local current_user

  before_each =>
    current_user = factory.Users!

  assert_log_contains_user = (log, user) ->
    objs = log\get_log_objects!
    assert.same 1, #objs
    assert.same ModerationLogObjects.object_types.user, objs[1].object_type
    assert.same user.id, objs[1].object_id

  create_ban = (post, user=current_user) ->
    in_request {
      :post
    }, =>
      @current_user = user
      @flow("bans")\create_ban!

  delete_ban = (post, user=current_user) ->
    in_request {
      :post
    }, =>
      @current_user = user
      @flow("bans")\delete_ban!

  describe "with category", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id

    show_bans = (opts, user=current_user) ->
      in_request {
        get: opts
      }, =>
        @current_user = user
        @flow("bans")\show_bans!

    it "bans user", ->
      other_user = factory.Users!

      create_ban {
        object_type: "category"
        object_id: category.id

        banned_user_id: other_user.id
        reason: " this user "
      }

      bans = Bans\select!
      assert.same 1, #bans
      ban = unpack bans

      assert.same other_user.id, ban.banned_user_id
      assert.same current_user.id, ban.banning_user_id
      assert.same category.id, ban.object_id
      assert.same Bans.object_types.category, ban.object_type
      assert.same "this user", ban.reason

      logs = ModerationLogs\select!
      assert.same 1, #logs
      log = unpack logs

      assert.same current_user.id, log.user_id
      assert.same category.id, log.category_id
      assert.same category.id, log.object_id
      assert.same ModerationLogs.object_types.category, log.object_type
      assert.same "category.ban", log.action
      assert.same "this user", log.reason

      assert_log_contains_user log, other_user

    describe "moderators", ->
      import Moderators from require "spec.community_models"

      local moderator

      before_each ->
        moderator = factory.Users!

        Moderators\create {
          object: category
          user_id: moderator.id
          accepted: true
        }

      it "lets moderator ban", ->
        other_user = factory.Users!

        assert.truthy create_ban {
          object_type: "category"
          object_id: category.id

          banned_user_id: other_user.id
          reason: [[ this user ]]
        }, moderator

        ban = unpack Bans\select!
        assert ban, "missing ban"
        assert.same moderator.id, ban.banning_user_id
        assert.same category.id, ban.object_id

      it "bans user from category higher up in moderation chain", ->
        other_user = factory.Users!

        child_category = factory.Categories {
          parent_category_id: category.id
        }

        child_category2 = factory.Categories {
          parent_category_id: child_category.id
        }

        assert.truthy create_ban {
          object_type: "category"
          object_id: child_category2.id
          banned_user_id: other_user.id
          reason: [[ this user ]]
        }, moderator

        ban = assert unpack(Bans\select!), "missing ban"
        assert.same moderator.id, ban.banning_user_id
        assert.same child_category2.id, ban.object_id

        ban\delete!

        -- it bans 
        assert.truthy create_ban {
          object_type: "category"
          object_id: child_category2.id
          target_category_id: category.id
          banned_user_id: other_user.id
          reason: [[ this user ]]
        }, moderator

        ban = assert unpack(Bans\select!), "missing ban"
        assert.same moderator.id, ban.banning_user_id
        assert.same category.id, ban.object_id


    it "doesn't let unrelated user ban", ->
      other_user = factory.Users!

      assert.has_error(
        ->
          create_ban {
            object_type: "category"
            object_id: category.id
            banned_user_id: current_user.id
            reason: [[ this user ]]
          }, other_user

        {
          message: { "invalid permissions" }
        }
      )

    it "unbans user", ->
      other_user = factory.Users!
      factory.Bans object: category, banned_user_id: other_user.id

      assert.true delete_ban {
        object_type: "category"
        object_id: category.id
        banned_user_id: other_user.id
      }

      assert.same 0, #Bans\select!

      logs = ModerationLogs\select!
      assert.same 1, #logs
      log = unpack logs

      assert.same current_user.id, log.user_id
      assert.same category.id, log.category_id
      assert.same category.id, log.object_id
      assert.same ModerationLogs.object_types.category, log.object_type
      assert.same "category.unban", log.action

      assert_log_contains_user log, other_user

    it "shows bans when there are no bans", ->
      bans = show_bans {
        object_type: "category"
        object_id: category.id
      }

      assert.same {}, bans

    it "shows bans", ->
      for i=1,2
        factory.Bans object: category

      bans = show_bans {
        object_type: "category"
        object_id: category.id
      }

      assert.same 2, #bans
      for ban in *bans
        assert.same category.id, ban.object_id

      bans_page_2 = show_bans {
        object_type: "category"
        object_id: category.id
        page: "2"
      }

      assert.same {}, bans_page_2

  describe "with topic", ->
    local topic

    before_each ->
      category = factory.Categories user_id: current_user.id
      topic = factory.Topics category_id: category.id

    it "bans user", ->
      other_user = factory.Users!
      ban = create_ban {
        object_type: "topic"
        object_id: topic.id
        banned_user_id: other_user.id
        reason: [[ this user ]]
      }

      assert ban, "expecting ban"

      bans = Bans\select!
      assert.same 1, #bans
      ban = unpack bans

      assert.same other_user.id, ban.banned_user_id
      assert.same current_user.id, ban.banning_user_id
      assert.same topic.id, ban.object_id
      assert.same Bans.object_types.topic, ban.object_type
      assert.same "this user", ban.reason

      -- check log
      logs = ModerationLogs\select!
      assert.same 1, #logs
      log = unpack logs

      assert.same current_user.id, log.user_id
      assert.same topic.category_id, log.category_id
      assert.same topic.id, log.object_id
      assert.same ModerationLogs.object_types.topic, log.object_type
      assert.same "topic.ban", log.action
      assert.same "this user", log.reason

      assert_log_contains_user log, other_user

    it "unban user", ->
      other_user = factory.Users!
      factory.Bans object: topic, banned_user_id: other_user.id

      assert delete_ban {
        object_type: "topic"
        object_id: topic.id
        banned_user_id: other_user.id
      }

      assert.same 0, #Bans\select!

      -- check log
      logs = ModerationLogs\select!
      assert.same 1, #logs
      log = unpack logs

      assert.same current_user.id, log.user_id
      assert.same topic.category_id, log.category_id
      assert.same topic.id, log.object_id
      assert.same ModerationLogs.object_types.topic, log.object_type
      assert.same "topic.unban", log.action

      assert_log_contains_user log, other_user

  describe "with category group", ->
    local category_group

    before_each ->
      category_group = factory.CategoryGroups user_id: current_user.id

    it "bans user from category group", ->
      user = factory.Users!

      ban = create_ban {
        object_type: "category_group"
        object_id: category_group.id
        banned_user_id: user.id
        reason: "get rid of this thing"
      }

      assert ban, "expecting ban"

      bans = Bans\select!
      assert.same 1, #bans
      ban = unpack bans

      assert.same user.id, ban.banned_user_id
      assert.same current_user.id, ban.banning_user_id
      assert.same category_group.id, ban.object_id
      assert.same Bans.object_types.category_group, ban.object_type

    it "unbans user from category group", ->
      user = factory.Users!
      factory.Bans object: category_group, banned_user_id: user.id

      assert delete_ban {
        object_type: "category_group"
        object_id: category_group.id
        banned_user_id: user.id
      }

      assert.same 0, Bans\count!

  -- flow is created as a sub flow of category flow
  describe "category bans flow", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id

    it "bans user", ->
      banned_user = factory.Users!

      ban = in_request {
        post: {
          category_id: category.id
          banned_user_id: banned_user.id
          reason: [[ this user ]]
        }
      }, =>
        @current_user = current_user
        flow = @flow("categories")\bans_flow!
        flow\create_ban!

      assert ban, "expecting ban"

      ban = unpack Bans\select!

      assert.same banned_user.id, ban.banned_user_id

      for log in *ModerationLogs\select!
        assert.same category.id, log.category_id

    it "unbans user", ->
      banned_user = factory.Users!
      factory.Bans object: category, banned_user_id: banned_user.id

      assert in_request {
        post: {
          category_id: category.id
          banned_user_id: banned_user.id
          reason: [[ this user ]]
        }
      }, =>
        @current_user = current_user
        flow = @flow("categories")\bans_flow!
        flow\delete_ban!

      assert.same 0, Bans\count!

      for log in *ModerationLogs\select!
        assert.same category.id, log.category_id

  describe "get_moderatable_categories", ->
    import Moderators from require "spec.community_models"

    get_moderatable_categories = (category) ->
      in_request {
        get: {
          object_type: "category"
          object_id: category.id
        }
      }, =>
        @current_user = current_user
        @flow("bans")\get_moderatable_categories!

    it "gets categories for non nested category", ->
      category = factory.Categories!

      Moderators\create {
        object: category
        user_id: current_user.id
        accepted: true
      }

      categories = get_moderatable_categories category

      assert.same {
        [category.id]: true
      }, { c.id, true for c in *categories }

    it "gets highest level category the user can moderate", ->
      a = factory.Categories!
      b = factory.Categories parent_category_id: a.id
      c = factory.Categories parent_category_id: b.id

      Moderators\create {
        object: b
        user_id: current_user.id
        accepted: true
      }

      -- moderating in c
      categories = get_moderatable_categories c

      assert.same {
        [b.id]: true
        [c.id]: true
      }, { c.id, true for c in *categories }

      -- moderating in b
      categories = get_moderatable_categories b

      assert.same {
        [b.id]: true
      }, { c.id, true for c in *categories }

    it "gets all categories for admin", ->
      stub(current_user, "is_admin")\returns "true"

      a = factory.Categories!
      b = factory.Categories parent_category_id: a.id
      c = factory.Categories parent_category_id: b.id

      categories = get_moderatable_categories c
      assert.same {
        [a.id]: true
        [b.id]: true
        [c.id]: true
      }, { c.id, true for c in *categories }

      categories = get_moderatable_categories b
      assert.same {
        [a.id]: true
        [b.id]: true
      }, { c.id, true for c in *categories }

      categories = get_moderatable_categories a
      assert.same {
        [a.id]: true
      }, { c.id, true for c in *categories }
