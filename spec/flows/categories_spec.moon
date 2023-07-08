import in_request, flow from require "spec.flow_helpers"

db = require "lapis.db"
factory = require "spec.factory"

import capture_errors_json from require "lapis.application"

import types from require "tableshape"

describe "categories", ->
  local current_user

  import Users from require "spec.models"

  import
    ActivityLogs
    Categories
    CategoryMembers
    CategoryTags
    CategoryPostLogs
    ModerationLogObjects
    ModerationLogs
    Moderators
    PendingPosts
    Posts
    Topics
    from require "spec.community_models"

  before_each ->
    current_user = factory.Users!

  new_category = (post, user=current_user) ->
    in_request {
      :post
    }, =>
      @current_user = user
      @flow("categories")\new_category!

  edit_category = (post, user=current_user, ...) ->
    args = {...}

    in_request {
      :post
    }, =>
      @current_user = user
      @flow("categories")\edit_category unpack args

  it "creates new category", ->
    new_category {
      "category[title]": "hello world"
      "category[membership_type]": "public"
      "category[voting_type]": "disabled"
      "category[short_description]": "This category is about something"
      "category[hidden]": "on"
    }

    category = unpack Categories\select!
    assert.truthy category

    assert.same current_user.id, category.user_id
    assert.same "hello world", category.title
    assert.same "This category is about something", category.short_description
    assert.falsy category.description

    assert.falsy category.archived
    assert.truthy category.hidden

    assert.same Categories.membership_types.public, category.membership_type
    assert.same Categories.voting_types.disabled, category.voting_type

    assert.same 1, ActivityLogs\count!
    log = unpack ActivityLogs\select!
    assert.same current_user.id, log.user_id
    assert.same category.id, log.object_id
    assert.same ActivityLogs.object_types.category, log.object_type
    assert.same "create", log\action_name!

  describe "with category", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id, description: "okay okay"

    describe "edit", ->
      it "edits category", ->
        -- this will get deleted because by default it updates category tags
        factory.CategoryTags category_id: category.id

        edit_category {
          category_id: category.id
          "category[title]": "\tThe good category  "
          "category[membership_type]": "members_only"
          "category[approval_type]": "pending"
          "category[voting_type]": "up"
          "category[topic_posting_type]": "moderators_only"
          "category[short_description]": "yeah yeah"
          "category[archived]": "on"
        }

        category\refresh!

        assert.same "The good category", category.title
        assert.same "the-good-category", category.slug
        assert.same "yeah yeah", category.short_description
        assert.nil category.description
        assert.truthy category.archived
        assert.falsy category.hidden

        assert.same Categories.membership_types.members_only, category.membership_type
        assert.same Categories.approval_types.pending, category.approval_type
        assert.same Categories.voting_types.up, category.voting_type
        assert.same Categories.topic_posting_types.moderators_only, category.topic_posting_type

        assert.same 1, ActivityLogs\count!
        log = unpack ActivityLogs\select!
        assert.same current_user.id, log.user_id
        assert.same category.id, log.object_id
        assert.same ActivityLogs.object_types.category, log.object_type
        assert.same "edit", log\action_name!

        assert.same {}, CategoryTags\select!

      it "partially updates category", ->
        category\update {
          archived: true
          short_description: "cool"

          category_order_type: Categories.category_order_types.topic_score
          membership_type: Categories.membership_types.members_only
          topic_posting_type: db.NULL
        }

        title = category.title

        edit_category {
          category_id: category.id
        }, current_user, { "archived", "short_description" }

        category\refresh!

        assert.false category.hidden
        assert.nil category.short_description

        -- these are unchanged
        assert.same Categories.category_order_types.topic_score, category.category_order_type
        assert.same Categories.membership_types.members_only, category.membership_type
        assert.nil category.topic_posting_type
        assert.same title, category.title

      it "makes category a directory", ->
        edit_category {
          category_id: category.id
          "category[type]": "directory"
        }, current_user, { "type" }

        category\refresh!
        assert.true category.directory

        -- back to post list
        edit_category {
          category_id: category.id
          "category[type]": "post_list"
        }, current_user, { "type" }

        category\refresh!
        assert.false category.directory

      it "doesn't let child category edit type", ->
        child = factory.Categories {
          parent_category_id: category.id
          user_id: current_user.id
        }

        assert.has_error(
          ->
            edit_category {
              category_id: child.id
              "category[type]": "directory"
            }, current_user, { "type" }

          {
            message: {
              "only root category can have type set"
            }
          }

        )

      it "doesn't create log when making no changes", ->
        ct = factory.CategoryTags {
          category_id: category.id
          tag_order: 1
        }

        edit_category {
          category_id: category.id
          "category[title]": category.title
          "category[description]": category.description
          "category_tags[1][id]": ct.id
          "category_tags[1][label]": ct.label
        }

        assert.same 0, ActivityLogs\count!

    it "should not let unknown user edit category", ->
      other_user = factory.Users!

      assert.has_error(
        ->
          edit_category {
            category_id: category.id
            "category[title]": "The good category"
            "category[membership_type]": "members_only"
          }, other_user

        {
          message: {
            "invalid category"
          }
        }
      )

    describe "tags", ->
      set_tags = (post, user=current_user) ->
        in_request {
          :post
        }, =>
          @current_user = user
          @flow("categories")\set_tags!

      it "sets tags", ->
        set_tags {
          category_id: category.id
          "category_tags[1][label]": "the first one"
          "category_tags[2][label]": "Second here"
          "category_tags[2][color]": "#dfdfee"
        }

        assert types.shape({
          types.partial {
            category_id: category.id
            tag_order: 1
            label: "the first one"
            slug: "the-first-one"
          }
          types.partial {
            category_id: category.id
            tag_order: 2
            label: "Second here"
            slug: "second-here"
            color: "#dfdfee"
          }
        }) category\get_tags!

      it "clears tags", ->
        for i=1,2
          factory.CategoryTags category_id: category.id

        set_tags {
          category_id: category.id
        }

        assert.same {}, category\get_tags!

      it "creates tag with emoji", ->
        set_tags {
          category_id: category.id
          "category_tags[1][label]": "Fanart 🎨"
          "category_tags[2][label]": "🤬"
        }

        -- since a slug can not be created, the emoji only tag is rejected
        assert types.shape({
          types.partial {
            slug: "fanart"
            label: "Fanart 🎨"
          }
        }) CategoryTags\select!

      it "edits tags", ->
        existing = for i=1,2
          factory.CategoryTags category_id: category.id, description: "wipe me"

        set_tags {
          category_id: category.id
          "category_tags[1][label]": "the first one"
          "category_tags[1][id]": "#{existing[2].id}"
          "category_tags[1][color]": "#daddad"
          "category_tags[2][label]": "new one"
          "category_tags[2][description]": "Hey there"
        }

        tags = category\get_tags!
        assert.same 2, #tags

        first, second = unpack tags
        assert.same existing[2].id, first.id
        t = existing[2]
        t\refresh!
        assert.same "the first one", t.label

        -- created a new second one
        assert.not.same existing[1].id, second.id

        assert.nil first.description
        assert.same "Hey there", second.description

      it "rejects tag that is too long", ->
        assert.has_error(
          ->
            set_tags {
              category_id: category.id
              "category_tags[1][label]": "the first one"
              "category_tags[1][color]": "#daddad"
              "category_tags[2][label]": "new one one one one one one oen oen oen eone n two three four file ve islfwele"
            }

          message: {"topic tag 2: label: expected text between 1 and 30 characters"}
        )

      it "doesn't fail when recreating tag of same slug", ->
        existing = factory.CategoryTags category_id: category.id

        set_tags {
          category_id: category.id
          "category_tags[1][label]": existing.label
        }

        assert.same 1, #category\get_tags!

      it "doesn't fail when trying to create dupes", ->
        set_tags {
          category_id: category.id
          "category_tags[1][label]": "alpha"
          "category_tags[1][label]": "alpha"
        }

        assert.same 1, #category\get_tags!

      it "edits tags through edit_category", ->
        factory.CategoryTags category_id: category.id

        edit_category {
          category_id: category.id
          "category_tags[1][label]": "some tag"
        }, current_user, {"category_tags"}

        assert types.shape({
          types.partial {
            category_id: category.id
            label: "some tag"
          }
        }) CategoryTags\select!

        assert types.shape({
          types.partial {
            user_id: current_user.id
            object_id: category.id
            object_type: assert ActivityLogs.object_types.category
            action: assert ActivityLogs.actions.category.edit
          }
        }) ActivityLogs\select!

    describe "recent posts", ->
      get_recent_posts = (opts) ->
        in_request {
          get: {
            category_id: category.id
          }
        }, =>
          @current_user = current_user
          @flow("categories")\recent_posts opts
          @posts, @pager

      it "gets empty recent posts", ->
        category\update directory: true
        recent_posts = get_recent_posts!
        assert.same {}, recent_posts

      it "gets category with posts from many topics", ->
        category\update directory: true

        posts = for i=1,2
          post = factory.Posts!
          CategoryPostLogs\create category_id: category.id, post_id: post.id
          post

        other_post = factory.Posts!
        CategoryPostLogs\create category_id: category.id + 10, post_id: other_post.id


        recent_posts = get_recent_posts!
        assert types.shape({
          types.shape {
            id: posts[2].id
          }, open: true

          types.shape {
            id: posts[1].id
          }, open: true
        }) recent_posts

      it "gets posts filtered", ->
        category\update directory: true

        -- topic post
        topic_post = factory.Posts!
        CategoryPostLogs\create category_id: category.id, post_id: topic_post.id

        -- reply post
        reply_post = factory.Posts topic_id: topic_post.topic_id
        CategoryPostLogs\create category_id: category.id, post_id: reply_post.id

        recent_topic_posts = get_recent_posts {
          filter: "topics"
        }

        assert types.shape({
          types.shape {
            id: topic_post.id
          }, open: true
        }) recent_topic_posts

        recent_replies = get_recent_posts {
          filter: "replies"
        }

        assert types.shape({
          types.shape {
            id: reply_post.id
          }, open: true
        }) recent_replies

      it "gets posts after date", ->
        category\update directory: true

        before_post = factory.Posts created_at: db.raw "now() at time zone 'utc' - '10 days'::interval"
        CategoryPostLogs\create category_id: category.id, post_id: before_post.id

        after_post = factory.Posts created_at: db.raw "now() at time zone 'utc' - '3 days'::interval"
        CategoryPostLogs\create category_id: category.id, post_id: after_post.id

        recent_posts = get_recent_posts {
          after_date: db.raw "now() at time zone 'utc' - '5 days'::interval"
        }

        assert types.shape({
          types.shape {
            id: after_post.id
          }, open: true
        }) recent_posts


  describe "show members", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id

    show_members = ->
      in_request {
        post: {
          category_id: category.id
          user_id: current_user.id
        }
      }, =>
        @current_user = current_user
        @flow("categories")\members_flow!\show_members!

    it "shows empty members", ->
      members = show_members!
      assert.same {}, members

    it "shows members", ->
      first = CategoryMembers\create {
        user_id: factory.Users!.id
        category_id: category.id
        accepted: true
      }

      second = CategoryMembers\create {
        user_id: factory.Users!.id
        category_id: category.id
        accepted: false
      }

      other = CategoryMembers\create {
        user_id: factory.Users!.id
        category_id: factory.Categories!.id
        accepted: true
      }

      members = show_members!

      assert types.shape({
        types.partial {
          category_id: category.id
          user_id: second.user_id
        }
        types.partial {
          category_id: category.id
          user_id: first.user_id
        }
      }) members

  describe "add/remove members", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id

    it "adds member", ->
      other_user = factory.Users!

      in_request {
        post: {
          category_id: category.id
          user_id: other_user.id
        }
      }, =>
        @current_user = current_user
        @flow("categories")\members_flow!\add_member!

      members = CategoryMembers\select!
      assert.same 1, #members

      member = unpack members
      assert.same category.id, member.category_id
      assert.same other_user.id, member.user_id
      assert.same false, member.accepted

    it "removes member", ->
      first = CategoryMembers\create {
        user_id: factory.Users!.id
        category_id: category.id
        accepted: true
      }

      in_request {
        post: {
          category_id: category.id
          user_id: first.user_id
        }
      }, =>
        @current_user = current_user
        @flow("categories")\members_flow!\remove_member!

      assert.same {}, CategoryMembers\select!

    it "fails to remove invalid member", ->
      first = CategoryMembers\create {
        user_id: factory.Users!.id
        category_id: factory.Categories!.id
        accepted: true
      }

      assert.has_error(
        ->
          in_request {
            post: {
              category_id: category.id
              user_id: first.user_id
            }
          }, =>
            @current_user = current_user
            @flow("categories")\members_flow!\remove_member!

          assert.same {}, CategoryMembers\select!
        message: {"user is not member"}
      )

    it "accepts membership", ->
      other_user = factory.Users!

      member = factory.CategoryMembers {
        user_id: other_user.id
        category_id: category.id
        accepted: false
      }

      in_request {
        post: {
          category_id: category.id
        }
      }, =>
        @current_user = other_user
        @flow("categories")\members_flow!\accept_member!

      member\refresh!
      assert.true member.accepted


    it "does not accept unininvited user", ->
      other_user = factory.Users!

      member = factory.CategoryMembers {
        user_id: other_user.id
        category_id: factory.Categories!.id
        accepted: false
      }

      assert.has_error(
        ->
          in_request {
            post: {
              category_id: category.id
            }
          }, =>
            @current_user = other_user
            @flow("categories")\members_flow!\accept_member!

        message: {"no pending membership"}
      )

  describe "moderation_logs", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id

    get_moderation_logs = (user=current_user) ->
      in_request {
        post: {
          category_id: category.id
        }
      }, =>
        @current_user = user
        @flow("categories")\moderation_logs!
        @moderation_logs, @page

    it "gets moderation log", ->
      log = ModerationLogs\create {
        category_id: category.id
        object: category
        user_id: current_user.id
        action: "did.something"
      }

      logs, page = get_moderation_logs!

      assert.same 1, page

      assert types.shape({
        types.partial {
          id: log.id
          object: types.table -- ensure it's preloaded
          user: types.table
        }
      }) logs

    it "doesn't get moderation log for unrelated user", ->
      other_user = factory.Users!
      assert.has_error(
        -> get_moderation_logs other_user
        message: {"invalid category"}
      )

  describe "pending posts", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id

    get_pending_posts = (user=current_user, get) ->
      in_request {
        :get
        post: {
          category_id: category.id
        }
      }, =>
        @current_user = user
        @flow("categories")\pending_posts!
        @pending_posts, @page

    edit_pending_post = (user=current_user, params) ->
      in_request {
        get: params
        post: {
          category_id: category.id
        }
      }, =>
        @current_user = user
        @flow("categories")\edit_pending_post!

    it "gets empty pending posts", ->
      pending_posts, page = get_pending_posts!
      assert.same {}, pending_posts
      assert.same 1, page

    describe "with pending posts", ->
      local pending_post

      before_each ->
        pending_post = factory.PendingPosts category_id: category.id

      it "gets pending posts", ->
        other_post = factory.PendingPosts!

        pending_posts, page = get_pending_posts!

        assert types.shape({
          types.partial {
            id: pending_post.id
          }
        }) pending_posts

      it "doesn't let stranger view pending posts", ->
        assert.has_error(
          -> get_pending_posts factory.Users!
          message: { "invalid category" }
        )

      it "filters by status", ->
        deleted_pp = factory.PendingPosts {
          category_id: category.id
          status: "deleted"
        }

        pending_posts = get_pending_posts current_user, {
          status: "deleted"
        }

        assert types.shape({
          types.partial {
            id: deleted_pp.id
          }
        }) pending_posts

      it "promotes pending post", ->
        s = spy.on(Posts.__base, "on_body_updated_callback")

        edit_pending_post current_user, {
          pending_post_id: pending_post.id
          action: "promote"
        }

        assert.same 0, PendingPosts\count!
        assert.same 1, Posts\count!
        assert.spy(s, "on_body_updated_callback").was.called!

      it "doesn't let stranger edit pending post", ->
        assert.has_error(
          ->
            edit_pending_post factory.Users!, {
              pending_post_id: pending_post.id
              action: "promote"
            }
          message: {"invalid pending post"}
        )

      it "deletes pending post", ->
        edit_pending_post current_user, {
          pending_post_id: pending_post.id
          action: "deleted"
        }

        assert.same 1, PendingPosts\count!
        assert.same 0, Posts\count!

        pending_post\refresh!
        assert.same PendingPosts.statuses.deleted, pending_post.status

  describe "set children", ->
    local category

    simplify_children = (children, fields={}) ->
      return for c in *children
        node = {
          title: c.title
          children: c.children and next(c.children) and simplify_children(c.children, fields) or nil
        }

        for f in *fields
          node[f] = c[f]

        node

    assert_children = (tree, category, ...) ->
      category = Categories\find category.id
      category\get_children!
      assert.same tree, simplify_children category.children, ...

    set_children = (post, user=current_user) ->
      in_request {
        :post
      }, =>
        @current_user = user
        @flow("categories")\set_children!

    before_each ->
      category = factory.Categories user_id: current_user.id

    it "sets empty categories", ->
      set_children {
        category_id: category.id
      }

    it "creates new categories", ->
      set_children {
        category_id: category.id
        "categories[1][title]": "alpha"
        "categories[1][archived]": "on"
        "categories[1][short_description]": " HHayllo World\n"
        "categories[2][title]": "beta"
        "categories[2][hidden]": "on"
        "categories[3][title]": "gamma"
      }

      assert_children {
        {
          title: "alpha"
          hidden: false
          archived: true
          short_description: "HHayllo World"
        }
        {title: "beta", hidden: true, archived: false}
        {title: "gamma", hidden: false, archived: false}
      }, category, {"archived", "hidden", "short_description"}

    it "doesn't too deeply nested categories", ->
      limits = require "community.limits"

      keys = {}
      for i=1,limits.MAX_CATEGORY_DEPTH+1
        if last = keys[#keys]
          table.insert keys, "#{last}[children][1]"
        else
          table.insert keys, "categories[1]"

      params = { category_id: category.id }
      for key in *keys
        params["#{key}[title]"] = "hello world"

      assert.has_error(
        -> set_children params
        message: {"category depth must be at most 4"}
      )

    it "doesn't set too many categories", ->
      limits = require "community.limits"
      params = { category_id: category.id }

      for i=1,limits.MAX_CATEGORY_CHILDREN+1
        params["categories[#{i}][title]"] = "category #{i}"

      assert.has_error(
        -> set_children params
        message: {"category can have at most 12 children"}
      )

    it "doesn't set too many categories in child", ->
      limits = require "community.limits"
      params = {
        category_id: category.id
        "categories[1][title]": "hello world"
      }

      for i=1,limits.MAX_CATEGORY_CHILDREN+1
        params["categories[1][children][#{i}][title]"] = "category #{i}"

      assert.has_error(
        -> set_children params
        message: {"category can have at most 12 children"}
      )


    it "creates new categories with nesting", ->
      set_children {
        category_id: category.id

        "categories[1][title]": "alpha"
        "categories[1][directory]": "on"
        "categories[1][children][1][title]": "alpha one"
        "categories[1][children][2][title]": "alpha two"
        "categories[2][title]": "beta"
        "categories[3][title]": "cow"
        "categories[3][children][1][title]": "cow moo"
        "categories[3][children][1][directory]": "on"
      }

      assert_children {
        {
          title: "alpha"
          directory: true
          children: {
            {title: "alpha one", directory: false}
            {title: "alpha two", directory: false}
          }
        }
        {title: "beta", directory: false}
        {
          title: "cow"
          directory: false
          children: {
            { title: "cow moo", directory: true }
          }
        }
      }, category, {"directory"}

    it "creates new nested child", ->
      b1 = factory.Categories parent_category_id: category.id, title: "before1"
      b2 = factory.Categories parent_category_id: category.id, title: "before2"
      b3 = factory.Categories parent_category_id: category.id, title: "before2"

      set_children {
        category_id: category.id

        "categories[1][id]": b1.id
        "categories[1][title]": "Hey cool category yeah"
        "categories[1][children][1][id]": b2.id
        "categories[1][children][1][title]": "Here's a child category"
        "categories[1][children][2][title]": "Another child category"
        "categories[2][id]": b3.id
        "categories[2][title]": "Another thing here?"
      }

      assert_children {
        {
          title: "Hey cool category yeah"
          children: {
            { title: "Here's a child category" }
            { title: "Another child category" }
          }
        }
        {
          title: "Another thing here?"
        }
      }, category

    it "edits existing children", ->
      b1 = factory.Categories parent_category_id: category.id, title: "before1"
      b2 = factory.Categories parent_category_id: category.id, title: "before2"

      set_children {
        category_id: category.id

        "categories[1][id]": "#{b1.id}"
        "categories[1][title]": "before1 updated"
        "categories[2][title]": "beta"
        "categories[3][id]": "#{b2.id}"
        "categories[3][title]": "before2"
      }

      assert_children {
        {title: "before1 updated"}
        {title: "beta"}
        {title: "before2"}
      }, category

      b1\refresh!
      assert.same category.id, b1.parent_category_id
      assert.same 1, b1.position
      assert.same "before1 updated", b1.title

      b2\refresh!
      assert.same category.id, b1.parent_category_id
      assert.same 1, b1.position
      assert.same "before1 updated", b1.title

    it "renests existing into new parent", ->
      b1 = factory.Categories parent_category_id: category.id, title: "before1"

      set_children {
        category_id: category.id

        "categories[1][title]": "new parent"
        "categories[1][children][1][id]": "#{b1.id}"
        "categories[1][children][1][title]": b1.title
      }

      assert_children {
        {
          title: "new parent"
          children: {
            { title: "before1" }
          }
        }
      }, category

      b1\refresh!
      parent = b1\get_parent_category!
      assert.same category.id, parent.parent_category_id

    it "deletes empty orphans", ->
      b1 = factory.Categories parent_category_id: category.id, title: "before1"
      b2 = factory.Categories parent_category_id: b1.id, title: "before2"

      set_children {
        category_id: category.id

        "categories[1][title]": "cool parent"
        "categories[1][children][1][id]": "#{b2.id}"
        "categories[1][children][1][title]": b2.title
      }

      b2\refresh!
      assert.not.same category.id, b2.parent_category_id
      assert.nil Categories\find id: b1.id

    it "archives orphan", ->
      b1 = factory.Categories parent_category_id: category.id, title: "orphan"
      topic = factory.Topics category_id: b1.id
      b1\increment_from_topic topic

      set_children {
        category_id: category.id
        "categories[1][title]": "new category"
      }

      b1\refresh!
      assert.true b1.archived
      assert.true b1.hidden
      assert.same 2, b1.position

    it "updates hidden/archive", ->
      set_children {
        category_id: category.id
        "categories[1][title]": "new category"
        "categories[1][hidden]": "on"
      }

      child = unpack category\get_children!
      assert.true child.hidden
      assert.false child.archived

      set_children {
        category_id: category.id
        "categories[1][id]": "#{child.id}"
        "categories[1][title]": "new category"
        "categories[1][archived]": "on"
      }

      child\refresh!

      assert.false child.hidden
      assert.true child.archived


    it "handles non-empty child in empty category", ->
      parent = factory.Categories parent_category_id: category.id, title: "parent"
      child = factory.Categories parent_category_id: parent.id, title: "child"
      topic = factory.Topics category_id: child.id
      child\increment_from_topic topic

      _, archived = assert set_children {
        category_id: category.id
        "categories[1][title]": "new category"
      }

      assert types.shape({
        types.partial { id: child.id }
      }) archived

      -- parent is deleted since it's empty
      assert.falsy Categories\find id: parent.id

      -- the child is preserved since it's non-empty, it becomes archived and hidden
      child\refresh!
      assert.true child.archived
      assert.true child.hidden
      assert.same 2, child.position

      assert_children {
        { title: "new category", archived: false, hidden: false }
        { title: "child", archived: true, hidden: true }
      }, category, {"archived", "hidden"}

