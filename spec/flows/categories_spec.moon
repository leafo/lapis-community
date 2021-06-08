import use_test_env from require "lapis.spec"
import in_request from require "spec.flow_helpers"

db = require "lapis.db"
factory = require "spec.factory"

import TestApp from require "spec.helpers"
import capture_errors_json from require "lapis.application"

import types from require "tableshape"

class CategoryApp extends TestApp
  @require_user!

  @before_filter =>
    CategoriesFlow = require "community.flows.categories"
    @flow = CategoriesFlow @

  "/show-members": capture_errors_json =>
    @flow\members_flow!\show_members!
    json: { success: true, members: @members }

  "/add-member": capture_errors_json =>
    @flow\members_flow!\add_member!
    json: { success: true }

  "/remove-member": capture_errors_json =>
    @flow\members_flow!\remove_member!
    json: { success: true }

  "/accept-member": capture_errors_json =>
    @flow\members_flow!\accept_member!
    json: { success: true }

  "/moderation-logs": capture_errors_json =>
    @flow\moderation_logs!
    json: {
      success: true
      page: @page
      moderation_logs: @moderation_logs
    }

  "/pending-posts": capture_errors_json =>
    @flow\pending_posts!
    json: {
      success: true
      page: @page
      pending_posts: @pending_posts
    }

  "/pending-post": capture_errors_json =>
    status, post = @flow\edit_pending_post!
    json: {
      :status
      :post
    }

  "/set-children": capture_errors_json =>
    @flow\set_children!
    json: { success: true }

  "/set-tags": capture_errors_json =>
    @flow\set_tags!
    json: { success: true }

describe "categories", ->
  use_test_env!

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
        edit_category {
          category_id: category.id
          "category[title]": "\tThe good category  "
          "category[membership_type]": "members_only"
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
        assert.same Categories.voting_types.up, category.voting_type
        assert.same Categories.topic_posting_types.moderators_only, category.topic_posting_type

        assert.same 1, ActivityLogs\count!
        log = unpack ActivityLogs\select!
        assert.same current_user.id, log.user_id
        assert.same category.id, log.object_id
        assert.same ActivityLogs.object_types.category, log.object_type
        assert.same "edit", log\action_name!

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
        edit_category {
          category_id: category.id
          "category[title]": category.title
          "category[description]": category.description
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
      it "sets tags", ->
        res = CategoryApp\get current_user, "/set-tags", {
          category_id: category.id
          "category_tags[1][label]": "the first one"
          "category_tags[2][label]": "Second here"
          "category_tags[2][color]": "#dfdfee"
        }

        assert.same {success: true}, res
        ts = for t in *category\get_tags!
          {
            category_id: t.category_id
            label: t.label
            slug: t.slug
            tag_order: t.tag_order
            color: t.color
          }

        assert.same {
          {
            category_id: category.id
            tag_order: 1
            label: "the first one"
            slug: "the-first-one"
          }
          {
            category_id: category.id
            tag_order: 2
            label: "Second here"
            slug: "second-here"
            color: "#dfdfee"
          }
        }, ts

      it "clears tags", ->
        for i=1,2
          factory.CategoryTags category_id: category.id

        res = CategoryApp\get current_user, "/set-tags", {
          category_id: category.id
        }

        assert.same {success: true}, res
        assert.same {}, category\get_tags!

      it "edits tags", ->
        existing = for i=1,2
          factory.CategoryTags category_id: category.id, description: "wipe me"

        res = CategoryApp\get current_user, "/set-tags", {
          category_id: category.id
          "category_tags[1][label]": "the first one"
          "category_tags[1][id]": "#{existing[2].id}"
          "category_tags[1][color]": "#daddad"
          "category_tags[2][label]": "new one"
          "category_tags[2][description]": "Hey there"
        }

        assert.same {success: true}, res
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
        res = CategoryApp\get current_user, "/set-tags", {
          category_id: category.id
          "category_tags[1][label]": "the first one"
          "category_tags[1][color]": "#daddad"
          "category_tags[2][label]": "new one one one one one one oen oen oen eone n two three four file ve islfwele"
        }

        assert.same {
          errors: {
            "topic tag 2: label: expected text between 1 and 30 characters"
          }
        }, res

      it "doesn't fail when recreating tag of same slug", ->
        existing = factory.CategoryTags category_id: category.id

        res = CategoryApp\get current_user, "/set-tags", {
          category_id: category.id
          "category_tags[1][label]": existing.label
        }

        assert.same 1, #category\get_tags!

      it "doesn't fail when trying to create dupes", ->
        res = CategoryApp\get current_user, "/set-tags", {
          category_id: category.id
          "category_tags[1][label]": "alpha"
          "category_tags[1][label]": "alpha"
        }

        assert.same 1, #category\get_tags!

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

    it "shows empty members", ->
      res = CategoryApp\get current_user, "/show-members", {
        category_id: category.id
        user_id: current_user.id
      }

      assert.nil res.errors
      assert.same {}, res.members

    it "shows members", ->
      CategoryMembers\create {
        user_id: factory.Users!.id
        category_id: category.id
        accepted: true
      }

      CategoryMembers\create {
        user_id: factory.Users!.id
        category_id: category.id
        accepted: false
      }

      res = CategoryApp\get current_user, "/show-members", {
        category_id: category.id
        user_id: current_user.id
      }

      assert.nil res.errors
      assert.same 2, #res.members
      assert.truthy res.members[1].user

  describe "add_member", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id

    it "should add member", ->
      other_user = factory.Users!

      res = CategoryApp\get current_user, "/add-member", {
        category_id: category.id
        user_id: other_user.id
      }

      members = CategoryMembers\select!
      assert.same 1, #members

      member = unpack members
      assert.same category.id, member.category_id
      assert.same other_user.id, member.user_id
      assert.same false, member.accepted

      assert.same { success: true }, res

    it "should accept member", ->
      other_user = factory.Users!

      factory.CategoryMembers {
        user_id: other_user.id
        category_id: category.id
        accepted: false
      }

      res = CategoryApp\get other_user, "/accept-member", {
        category_id: category.id
      }

      assert.same { success: true }, res

    it "should not accept unininvited user", ->
      other_user = factory.Users!
      res = CategoryApp\get other_user, "/accept-member", {
        category_id: category.id
      }

      assert.same { errors: {"no pending membership"} }, res

  describe "moderation_logs", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id

    it "gets moderation log", ->
      ModerationLogs\create {
        category_id: category.id
        object: category
        user_id: current_user.id
        action: "did.something"
      }

      res = CategoryApp\get current_user, "/moderation-logs", {
        category_id: category.id
      }

      assert.truthy res.moderation_logs
      assert.same 1, #res.moderation_logs

    it "doesn't get moderation log for unrelated user", ->
      other_user = factory.Users!
      res = CategoryApp\get other_user, "/moderation-logs", {
        category_id: category.id
      }

      assert.same {errors: {"invalid category"}}, res

  describe "pending posts", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id

    it "gets empty pending posts", ->
      res = CategoryApp\get current_user, "/pending-posts", {
        category_id: category.id
      }

      assert.same {}, res.pending_posts

    describe "with pending posts", ->
      local pending_post

      before_each ->
        pending_post = factory.PendingPosts category_id: category.id

      it "gets pending posts", ->
        res = CategoryApp\get current_user, "/pending-posts", {
          category_id: category.id
        }
        assert.same 1, #res.pending_posts
        assert.same pending_post.id, res.pending_posts[1].id

      it "doesn't let stranger view pending posts", ->
        res = CategoryApp\get factory.Users!, "/pending-posts", {
          category_id: category.id
        }
        assert.truthy res.errors

      it "doesn't get incorrect satus", ->
        res = CategoryApp\get current_user, "/pending-posts", {
          category_id: category.id
          status: "deleted"
        }
        assert.same {}, res.pending_posts

      it "promotes pending post", ->
        s = spy.on(Posts.__base, "on_body_updated_callback")

        res = CategoryApp\get current_user, "/pending-post", {
          category_id: category.id
          pending_post_id: pending_post.id
          action: "promote"
        }

        assert.same 0, PendingPosts\count!
        assert.same 1, Posts\count!
        assert.spy(s, "on_body_updated_callback").was.called!

      it "doesn't let stranger edit pending post", ->
        res = CategoryApp\get factory.Users!, "/pending-post", {
          category_id: category.id
          pending_post_id: pending_post.id
          action: "promote"
        }

        assert.truthy res.errors

      it "deletes pending post", ->
        res = CategoryApp\get current_user, "/pending-post", {
          category_id: category.id
          pending_post_id: pending_post.id
          action: "deleted"
        }

        assert.same 1, PendingPosts\count!
        assert.same 0, Posts\count!

        pending_post\refresh!
        assert.same PendingPosts.statuses.deleted, pending_post.status

  describe "set children", =>
    local category

    simplify_children = (children) ->
      return for c in *children
        {
          title: c.title
          children: c.children and next(c.children) and simplify_children(c.children) or nil
        }

    assert_children = (tree, category) ->
      category = Categories\find category.id
      category\get_children!
      assert.same tree, simplify_children category.children

    before_each ->
      category = factory.Categories user_id: current_user.id

    it "should set empty cateogires", ->
      CategoryApp\get current_user, "/set-children", {
        category_id: category.id
      }

    it "creates new categories", ->
      res = CategoryApp\get current_user, "/set-children", {
        category_id: category.id
        "categories[1][title]": "alpha"
        "categories[2][title]": "beta"
      }

      assert.nil res.errors
      assert_children {
        {title: "alpha"}
        {title: "beta"}
      }, category

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

      res = CategoryApp\get current_user, "/set-children", params
      assert.same {
        errors: {
          "category depth must be at most 4"
        }
      }, res

    it "doesn't set too many categories", ->
      limits = require "community.limits"
      params = { category_id: category.id }

      for i=1,limits.MAX_CATEGORY_CHILDREN+1
        params["categories[#{i}][title]"] = "category #{i}"

      res = CategoryApp\get current_user, "/set-children", params
      assert.same {
        errors: {
          "category can have at most 12 children"
        }
      }, res

    it "doesn't set too many categories in child", ->
      limits = require "community.limits"
      params = {
        category_id: category.id
        "categories[1][title]": "hello world"
      }

      for i=1,limits.MAX_CATEGORY_CHILDREN+1
        params["categories[1][children][#{i}][title]"] = "category #{i}"

      res = CategoryApp\get current_user, "/set-children", params
      assert.same {
        errors: {
          "category can have at most 12 children"
        }
      }, res


    it "creates new categories with nesting", ->
      res = CategoryApp\get current_user, "/set-children", {
        category_id: category.id

        "categories[1][title]": "alpha"
        "categories[1][children][1][title]": "alpha one"
        "categories[1][children][2][title]": "alpha two"
        "categories[2][title]": "beta"
        "categories[3][title]": "cow"
        "categories[3][children][1][title]": "cow moo"
      }

      assert.nil res.errors
      assert_children {
        {
          title: "alpha"
          children: {
            {title: "alpha one"}
            {title: "alpha two"}
          }
        }
        {title: "beta"}
        {
          title: "cow"
          children: {
            {title: "cow moo"}
          }
        }
      }, category

    it "creates new nested child", ->
      b1 = factory.Categories parent_category_id: category.id, title: "before1"
      b2 = factory.Categories parent_category_id: category.id, title: "before2"
      b3 = factory.Categories parent_category_id: category.id, title: "before2"

      res = CategoryApp\get current_user, "/set-children", {
        category_id: category.id

        "categories[1][id]": b1.id
        "categories[1][title]": "Hey cool category yeah"
        "categories[1][children][1][id]": b2.id
        "categories[1][children][1][title]": "Here's a child category"
        "categories[1][children][2][title]": "Another child category"
        "categories[2][id]": b3.id
        "categories[2][title]": "Another thing here?"
      }

      assert.nil res.errors
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

      res = CategoryApp\get current_user, "/set-children", {
        category_id: category.id

        "categories[1][id]": "#{b1.id}"
        "categories[1][title]": "before1 updated"
        "categories[2][title]": "beta"
        "categories[3][id]": "#{b2.id}"
        "categories[3][title]": "before2"
      }

      assert.nil res.errors
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

      res = CategoryApp\get current_user, "/set-children", {
        category_id: category.id

        "categories[1][title]": "new parent"
        "categories[1][children][1][id]": "#{b1.id}"
        "categories[1][children][1][title]": b1.title
      }

      assert.nil res.errors
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

      res = CategoryApp\get current_user, "/set-children", {
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

      res = CategoryApp\get current_user, "/set-children", {
        category_id: category.id
        "categories[1][title]": "new category"
      }

      b1\refresh!
      assert.true b1.archived
      assert.true b1.hidden
      assert.same 2, b1.position

    it "updates hidden/archive", ->
      res = CategoryApp\get current_user, "/set-children", {
        category_id: category.id
        "categories[1][title]": "new category"
        "categories[1][hidden]": "on"
      }

      child = unpack category\get_children!
      assert.true child.hidden
      assert.false child.archived

      res = CategoryApp\get current_user, "/set-children", {
        category_id: category.id
        "categories[1][id]": "#{child.id}"
        "categories[1][title]": "new category"
        "categories[1][archived]": "on"
      }

      child\refresh!

      assert.false child.hidden
      assert.true child.archived

