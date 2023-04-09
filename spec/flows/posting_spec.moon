-- TODO: move this to respetive category/topic specs
import in_request from require "spec.flow_helpers"

factory = require "spec.factory"

db = require "lapis.db"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

PostsFlow = require "community.flows.posts"

import Users from require "models"

import types from require "tableshape"
import instance_of from require "tableshape.moonscript"

describe "posting flow", ->
  local current_user

  import Users from require "spec.models"

  import
    Categories
    CategoryTags
    Moderators
    CommunityUsers
    PostEdits
    Votes
    Posts
    TopicParticipants
    Topics
    ActivityLogs
    from require "spec.community_models"

  before_each ->
    current_user = factory.Users!

  new_topic = (post, set_req) ->
    in_request { :post }, =>
      if set_req
        set_req @

      @current_user = current_user
      @flow("topics")\new_topic!
      @

  delete_topic = (post, user=current_user) ->
    in_request { :post }, =>
      @current_user = user
      @flow("topics")\delete_topic!

  describe "new topic", ->
    it "errors with blank post request", ->
      assert.has_error ->
        new_topic { }

    it "errors with bad category", ->
      assert.has_error(
        ->
          new_topic {
            category_id: 0
            "topic[title]": "hello"
            "topic[body]": "world"
          }

        {
          message: {"invalid category"}
        }
      )

    it "errors with empty body", ->
      assert.has_error(
        ->
          new_topic {
            category_id: factory.Categories!.id
            "topic[title]": "hello"
            "topic[body]": ""
          }
        {
          message: {"body: expected text between 1 and 20480 characters"}
        }
      )

    it "errors with empty html body", ->
      assert.has_error(
        ->
          new_topic {
            category_id: factory.Categories!.id
          "topic[title]": "hello"
          "topic[body]": " <ol><li>   </ol>"
          }
        {
          message: {"body must be provided"}
        }
      )

    it "creates new topic", ->
      category = factory.Categories!

      new_topic {
        category_id: category.id
        "topic[title]": "Hello world"
        "topic[body]": "This is the body"
      }

      topic = unpack Topics\select!
      post = unpack Posts\select!

      assert (types.shape {
        category_id: category.id
        user_id: current_user.id
        title: "Hello world"
        category_order: 1

        protected: false
        locked: false
        permanent: false
        deleted: false
        sticky: false
        posts_count: 1
        root_posts_count: 1
        status: Topics.statuses.default
        last_post_id: post.id
      }, open: true) topic


      assert (types.shape {
        body_format: Posts.body_formats.html
        user_id: current_user.id
        topic_id: topic.id
        body: "This is the body"
        depth: 1
        status: Posts.statuses.default
        deleted: false
        post_number: 1
      }, open: true) post

      category\refresh!

      assert (types.shape {
        last_topic_id: topic.id
        topics_count: 1
      }, open: true) category

      cu = CommunityUsers\for_user(current_user)

      assert (types.shape {
        topics_count: 1
        posts_count: 1
      }, open: true) cu

      tps = TopicParticipants\select "where topic_id = ?", topic.id
      assert (types.shape {
        types.shape {
          user_id: current_user.id
          posts_count: 1
        }, open: true
      }) tps


      assert.same 1, ActivityLogs\count!
      logs = ActivityLogs\select!

      assert (types.shape {
        types.shape {
          user_id: current_user.id
          object_id: topic.id
          object_type: ActivityLogs.object_types.topic
          action: ActivityLogs.actions.topic.create
        }, open: true
      }) logs


    it "creates new topic with body format", ->
      category = factory.Categories!

      new_topic {
        category_id: category.id
        "topic[title]": "Hello world"
        "topic[body]": "This is the body"
        "topic[body_format]": "markdown"
      }

      post = unpack Posts\select!

      assert types.partial({
        body_format: Posts.body_formats.markdown
      }) post

    it "creates new topic with tags", ->
      category = factory.Categories!
      factory.CategoryTags slug: "hello", category_id: category.id

      new_topic {
        category_id: category.id
        "topic[title]": "Hello world  "
        "topic[body]": "This is the body\t"
        "topic[tags]": "hello"
      }

      topic = unpack Topics\select!
      assert.same {"hello"}, [t.slug for t in *topic\get_tags!]

    it "lets moderator create sticky topic", ->
      category = factory.Categories!

      factory.Moderators {
        user_id: current_user.id
        object: category
      }

      new_topic {
        category_id: category.id
        "topic[title]": "Hello"
        "topic[body]": "World"
        "topic[sticky]": "on"
      }

      topic = unpack Topics\select!
      assert.true topic.sticky
      assert.false topic.locked

    it "lets moderator create locked topic", ->
      category = factory.Categories!

      factory.Moderators {
        user_id: current_user.id
        object: category
      }

      new_topic {
        category_id: category.id
        "topic[title]": "Hello"
        "topic[body]": "World"
        "topic[locked]": "on"
      }

      topic = unpack Topics\select!
      assert.false topic.sticky
      assert.true topic.locked

    it "doesn't let regular user create sticky or locked topic", ->
      category = factory.Categories!

      new_topic {
        category_id: category.id
        "topic[title]": "Hello"
        "topic[body]": "World"
        "topic[sticky]": "on"
        "topic[locked]": "on"
      }

      topic = unpack Topics\select!
      assert.false topic.sticky
      assert.false topic.locked

    it "posts new topic with score based category order", ->
      category = factory.Categories  category_order_type: "topic_score"

      new_topic {
        category_id: category.id
        "topic[title]": "Hello world"
        "topic[body]": "This is the body"
      }

      topic = unpack Topics\select!
      assert.not.same 1, topic.category_order

    it "calls on_body_updated_callback when creating topic", ->
      s = spy.on(Posts.__base, "on_body_updated_callback")

      category = factory.Categories!

      new_topic {
        category_id: category.id
        "topic[title]": "call the"
        "topic[body]": "method please"
      }

      assert.spy(s, "on_body_updated_callback").was.called!

    it "blocks new topic when posting permission is blocked", ->
      category = factory.Categories!

      cu = CommunityUsers\for_user current_user
      cu\update {
        posting_permission: CommunityUsers.posting_permissions.blocked
      }

      assert.has_error(
        ->
          new_topic {
            category_id: category.id
            "topic[title]": "Hello world"
            "topic[body]": "This is the body"
          }

        {
          message: {"your account is not able to post at this time"}
        }
      )

    it "checks posting permission only_own", ->
      category = factory.Categories!

      cu = CommunityUsers\for_user current_user
      cu\update {
        posting_permission: CommunityUsers.posting_permissions.only_own
      }

      assert.has_error(
        ->
          new_topic {
            category_id: category.id
            "topic[title]": "Hello world"
            "topic[body]": "This is the body"
          }

        {
          message: {"your account is not able to post at this time"}
        }
      )

      -- make them the owner of the category
      category\update {
        user_id: current_user.id
      }

      cu\refresh!

      new_topic {
        category_id: category.id
        "topic[title]": "Hello world"
        "topic[body]": "This is the body"
      }

      assert.same 1, Topics\count!

    describe "warnings", ->
      import Warnings, PendingPosts from require "spec.community_models"

      it "blocks topic due to warning", ->
        category = factory.Categories!

        w = Warnings\create {
          user_id: current_user.id
          restriction: Warnings.restrictions.block_posting
          duration: "1 week"
        }

        assert.true w\is_active!, "warning should be active"

        local req

        assert.has_error(
          ->
            new_topic {
              category_id: category.id
              "topic[title]": "Hello world"
              "topic[body]": "This is the body"
            }, (r) -> req = r
          { message: {"your account has an active warning"} }
        )

        {:topic, :pending_post, :warning} = req

        assert.nil topic, "no topic should be created on request"
        assert.nil pending_post, "no pending post should be created on request"
        -- assert.truthy warning, "expect warning to be set on request"

      it "allows user to create topic with blocking warning if they own category", ->
        category = factory.Categories user_id: current_user.id

        w = Warnings\create {
          user_id: current_user.id
          restriction: Warnings.restrictions.block_posting
          duration: "1 week"
        }

        assert.true w\is_active!, "warning should be active"

        {:topic, :post, :pending_post, :warning} = new_topic {
          category_id: category.id
          "topic[title]": "Hello world"
          "topic[body]": "This is the body"
        }

        assert.truthy topic, "no topic should be created on request"
        assert.nil pending_post, "pending post should not be set"
        assert.nil warning, "warning should not be set"

      it "creates topic as pending if user has warning", ->
        category = factory.Categories!

        w = Warnings\create {
          user_id: current_user.id
          restriction: Warnings.restrictions.pending_posting
          duration: "1 week"
        }

        {:topic, :pending_post, :warning} = new_topic {
          category_id: category.id
          "topic[title]": "Hello world"
          "topic[body]": "This is the body"
        }

        assert.nil topic, "no topic should be created"
        assert.truthy pending_post, "expected pending post to be created"
        assert.truthy warning, "expecting warning to be set"

      it "user with pending warning can still create topic if they own category", ->
        category = factory.Categories user_id: current_user.id

        w = Warnings\create {
          user_id: current_user.id
          restriction: Warnings.restrictions.pending_posting
          duration: "1 week"
        }

        {:topic, :pending_post, :warning} = new_topic {
          category_id: category.id
          "topic[title]": "Hello world"
          "topic[body]": "This is the body"
        }

        assert.truthy topic, "expecting topic to be created"
        assert.nil pending_post, "expecting pending post to not be set"
        assert.nil warning, "expecting warning to not be set"

    describe "pending topic", ->
      import PendingPosts from require "spec.community_models"

      local category

      before_each ->
        category = factory.Categories!
        category\update {
          approval_type: Categories.approval_types.pending
        }

      it "force_pending", ->
        some_category = factory.Categories!

        {:topic, :pending_post} = in_request {
          post: {
            category_id: some_category.id
            "topic[title]": "Hello world"
            "topic[body]": "This is the body"
          }
        }, =>
          @current_user = current_user
          @flow("topics")\new_topic {
            force_pending: true
          }
          @

        assert.nil topic, "no topic should be created"
        assert.truthy pending_post, "pending post should be created"

      it "creates a pending topic post", ->
        CategoryTags\create {
          slug: "hello-world"
          category_id: category.id
        }

        new_topic {
          category_id: category.id
          "topic[title]": "Hello world"
          "topic[body]": "This is the body"
          "topic[body_format]": "markdown"
          "topic[tags]": "hello-world"
        }

        assert.same {}, Topics\select!, "topic should not be created"
        assert.same {}, Posts\select!, "post should not be created"


        pending_posts = PendingPosts\select!

        assert types.shape({
          types.partial {
            status: PendingPosts.statuses.pending
            reason: PendingPosts.statuses.manual
            category_id: category.id
            topic_id: types.nil
            parent_post_id: types.nil
            title: "Hello world"
            body: "This is the body"
            body_format: Posts.body_formats.markdown
            user_id: current_user.id
            data: types.shape {
              topic_tags: types.shape { "hello-world" }
            }
          }
        }) pending_posts

        assert types.shape({
          types.partial {
            object_type: ActivityLogs.object_types.pending_post
            object_id: pending_posts[1].id
            user_id: current_user.id
            action: ActivityLogs.actions.pending_post.create_topic
            data: types.shape {
              category_id: category.id
            }
          }
        }) ActivityLogs\select!

        assert pending_posts[1]\get_activity_log_create!

        assert pending_posts[1]\promote!

        assert.same {}, PendingPosts\select!, "pending post should be removed after promoting"

        assert types.shape({
          types.partial {
            title: "Hello world"
            user_id: current_user.id
            category_id: category.id
            tags: types.shape { "hello-world" }
          }
        }) Topics\select!

        assert types.shape({
          types.partial {
            body: "This is the body"
            body_format: Posts.body_formats.markdown
            user_id: current_user.id
          }
        }) Posts\select!

      it "skips pending restriction if user is moderator", ->
        category\update user_id: current_user.id

        {:pending_post, :topic} = new_topic {
          category_id: category.id
          "topic[title]": "Hello world"
          "topic[body]": "This is the body"
          "topic[body_format]": "markdown"
        }

        assert.same nil, pending_post, "pending post should not be created"
        assert.truthy topic, "topic should be created"

        assert.same 0, PendingPosts\count!, "no pending posts should exist"

  describe "new post", ->
    local topic

    before_each ->
      -- note this isn't a full topic, it has no first post
      topic = factory.Topics!

    new_post = (post={}, set_req) ->
      in_request { :post }, =>
        if set_req
          set_req @

        @topic = topic
        @current_user = current_user
        @flow("posts")\new_post!
        @

    it "errors with empty body", ->
      assert.has_error(
        ->
          new_post {
            "post[body]": ""
          }
        {
          message: {"post: body: expected text between 1 and 20480 characters"}
        }
      )

    it "errors with invalid format", ->
      assert.has_error(
        ->
          new_post {
            "post[body]": "Hello"
            "post[body_format]": "theheck"
          }
        {
          message: {"post: body_format: expected enum(html, markdown), or empty"}
        }
      )

    it "errors with empty html body", ->
      assert.has_error(
        ->
          new_post {
            "post[body]": "<div></div>"
          }
        {
          message: {"body must be provided"}
        }
      )

    it "creates new post", ->
      new_post {
        topic_id: topic.id
        "post[body]": "This is post body    "
      }

      topic\refresh!
      post = unpack Posts\select!

      assert (types.partial {
        user_id: current_user.id
        topic_id: topic.id
        body: "This is post body"
        body_format: Posts.body_formats.html

        depth: 1
        status: Posts.statuses.default
        deleted: false
        post_number: 1
      }) post

      assert (types.partial {
        posts_count: 1
        root_posts_count: 1
        status: Topics.statuses.default
        category_order: 2

        -- although this is the first post, there is no circumstance where the
        -- first post would normally get posted through /new-post, so we assume
        -- last_post_id is set
        last_post_id: post.id

      }) topic

      cu = CommunityUsers\for_user(current_user)

      assert (types.partial {
        topics_count: 0
        posts_count: 1
      }) cu

      -- 1 less because factory didn't seed topic participants
      tps = TopicParticipants\select "where topic_id = ?", topic.id
      assert (types.shape {
        types.partial {
          user_id: current_user.id
          posts_count: 1
        }
      }) tps


      assert.same 1, ActivityLogs\count!
      logs = ActivityLogs\select!

      assert (types.shape {
        types.partial {
          user_id: current_user.id
          object_id: post.id
          object_type: ActivityLogs.object_types.posts
          action: ActivityLogs.actions.post.create
        }
      }) logs

    it "creates two posts", ->
      for i=1,2
        new_post {
          topic_id: topic.id
          "post[body]": "This is post body"
        }

      tps = TopicParticipants\select "where topic_id = ?", topic.id
      assert.same 1, #tps
      assert.same 2, tps[1].posts_count

    it "creates new post with body format", ->
      new_post {
        topic_id: topic.id
        "post[body]": "This is post body"
        "post[body_format]": "markdown"
      }

      topic\refresh!
      post = unpack Posts\select!

      assert (types.shape {
        body_format: Posts.body_formats.markdown
      })

    it "calls on_body_updated_callback when creating post", ->
      s = spy.on(Posts.__base, "on_body_updated_callback")

      new_post {
        topic_id: topic.id
        "post[body]": "will call the callback"
      }

      assert.spy(s, "on_body_updated_callback").was.called!

    it "creates post with before_create_callback", ->
      called = false

      {:post, :pending_post} = in_request {
        post: {
          "topic_id": topic.id
          "post[body]": "Hello world"
        }
      }, =>
        @current_user = current_user
        @flow("posts")\new_post {
          before_create_callback: (obj) ->
            called = true
            assert.same {
              needs_approval: false
              body_format: Posts.body_formats.html
              body: "Hello world"
            }, obj


            obj.body = "What the heck?"
            obj.body_format = "markdown"
        }
        @

      assert.true called

      assert (types.partial {
        body_format: Posts.body_formats.markdown
        body: "What the heck?"
        topic_id: topic.id
      }) post

      assert.nil pending_post

    it "blocks new post when posting permission is blocked", ->
      cu = CommunityUsers\for_user current_user
      cu\update {
        posting_permission: CommunityUsers.posting_permissions.blocked
      }

      assert.has_error(
        ->
          new_post {
            topic_id: topic.id
            "post[body]": "This is post body    "
          }

        {
          message: {"your account is not able to post at this time"}
        }
      )

      assert.same 0, Posts\count!

      -- doesn't let them post in own topic
      topic\update {
        user_id: current_user.id
      }

      assert.has_error(
        ->
          new_post {
            topic_id: topic.id
            "post[body]": "This is post body    "
          }

        {
          message: {"your account is not able to post at this time"}
        }
      )

    it "blocks posting with only_own", ->
      cu = CommunityUsers\for_user current_user
      cu\update {
        posting_permission: CommunityUsers.posting_permissions.only_own
      }

      assert.false topic\allowed_to_moderate(current_user),
        "current user should not be moderator"

      assert.has_error(
        ->
          new_post {
            topic_id: topic.id
            "post[body]": "hello world"
          }

        {
          message: {"your account is not able to post at this time"}
        }
      )

      assert.same 0, Posts\count!

      -- even if they have created the topic, if they aren't a moderator then
      -- they can't post in it
      do
        topic\update {
          user_id: current_user.id
        }

        -- clear all caches
        topic = Topics\find topic.id

        assert.has_error(
          ->
            new_post {
              topic_id: topic.id
              "post[body]": "hello world"
            }

          {
            message: {"your account is not able to post at this time"}
          }
        )

      -- category owner is a moderator, can post!
      do
        category = topic\get_category!
        category\update user_id: current_user.id

        -- clear all caches
        topic = Topics\find topic.id

        new_post {
          topic_id: topic.id
          "post[body]": "hello world"
        }


    describe "warnings", ->
      import Warnings, PendingPosts from require "spec.community_models"

      it "blocks posting of new post due to warning", ->
        w = Warnings\create {
          user_id: current_user.id
          restriction: Warnings.restrictions.block_posting
          duration: "1 week"
        }

        assert.true w\is_active!, "warning should be active"

        local req

        assert.has_error(
          ->
            new_post {
              "post[body]": "hello world"
            }, (r) -> req = r
          { message: { "your account has an active warning" } }
        )

        -- ensure that the warning is placed on the request object
        -- and that no post or pending post is there
        assert_request = types.assert types.partial {
          warning: instance_of(Warnings)
          post: types.nil
          pending_post: types.nil
        }

        assert_request req

        assert.same 0, Posts\count!
        assert.same 0, PendingPosts\count!

      it "doesn't block posting of new post with warning if user owns category", ->
        category = topic\get_category!
        -- set them as owner
        category\update user_id: current_user.id

        w = Warnings\create {
          user_id: current_user.id
          restriction: Warnings.restrictions.block_posting
          duration: "1 week"
        }

        assert.true w\is_active!, "warning should be active"

        assert.true (topic\allowed_to_edit current_user)

        new_post {
          "post[body]": "hello world"
        }

      it "makes pending post due to warning", ->
        w = Warnings\create {
          user_id: current_user.id
          restriction: Warnings.restrictions.pending_posting
          duration: "1 week"
        }

        assert.true w\is_active!, "warning should be active"

        {:pending_post, :post, :warning} = new_post {
          "post[body]": "hello world"
        }

        assert.nil post
        assert instance_of(PendingPosts) pending_post
        assert instance_of(Warnings) warning

        assert.same 0, Posts\count!
        assert.same 1, PendingPosts\count!

      it "warning doesn't block pending post if the user owns category", ->
        category = topic\get_category!
        -- set them as owner
        category\update user_id: current_user.id


        w = Warnings\create {
          user_id: current_user.id
          restriction: Warnings.restrictions.pending_posting
          duration: "1 week"
        }

        assert.true w\is_active!, "warning should be active"

        {:pending_post, :post, :warning} = new_post {
          "post[body]": "hello world"
        }

        assert instance_of(Posts) post
        assert.nil pending_post
        assert.nil warning

    describe "parent_post_id", ->
      import Blocks from require "spec.community_models"

      it "fails with invalid parent_post_id value", ->
        post = factory.Posts topic_id: topic.id

        assert.has_error(
          ->
            new_post {
              topic_id: topic.id
              parent_post_id: "cool"
              "post[body]": "This is a sub message"
            }

          { message: {"parent_post_id: expected database ID integer, or empty"} }
        )

      it "fails with non-existent parent post", ->
        post = factory.Posts topic_id: topic.id

        assert.has_error(
          ->
            new_post {
              topic_id: topic.id
              parent_post_id: post.id + 1
              "post[body]": "This is a sub message"
            }

          { message: {"invalid parent post"} }
        )

      it "fails if parent post belongs to another topic", ->
        post = factory.Posts!

        assert.has_error(
          ->
            new_post {
              topic_id: topic.id
              parent_post_id: post.id
              "post[body]": "This is a sub message"
            }

          { message: {"parent post doesn't belong to same topic"} }
        )

      it "fails if parent post doesn't allow replies", ->
        post = factory.Posts topic_id: topic.id
        post\update deleted: true

        assert.has_error(
          ->
            new_post {
              topic_id: topic.id
              parent_post_id: post.id
              "post[body]": "This is a sub message"
            }

          { message: {"can't reply to post"} }
        )

      it "fails if parent poster has blocked user", ->
        post = factory.Posts topic_id: topic.id
        Blocks\create {
          blocking_user_id: post.user_id
          blocked_user_id: current_user.id
        }

        local req

        assert.has_error(
          ->
            new_post {
              topic_id: topic.id
              parent_post_id: post.id
              "post[body]": "This is a sub message"
            }, (r) -> req = r

          { message: {"can't reply to post"} }
        )


        {:block, :post} = req
        assert.truthy block
        assert.nil post

      it "posts a threaded post", ->
        post = factory.Posts topic_id: topic.id

        {post: child_post} = new_post {
          topic_id: topic.id
          parent_post_id: post.id
          "post[body]": "This is a sub message"
        }

        posts = Posts\select!
        assert.same 2, #posts

        child_post = Posts\find child_post.id
        assert.same post.id, child_post.parent_post_id

    describe "pending post", ->
      import PendingPosts from require "spec.community_models"
      local category

      before_each ->
        category = topic\get_category!
        category\update {
          approval_type: Categories.approval_types.pending
        }

      new_pending_post = (opts) ->
        {:pending_post} = new_post opts
        assert instance_of(PendingPosts) pending_post
        pending_post

      it "creates pending post instead of new post", ->
        pending_post = new_pending_post {
          topic_id: topic.id
          "post[body]": "  Hello from my pending post  "
        }

        assert.same 0, Posts\count!
        assert.same 1, PendingPosts\count!

        assert types.shape({
          id: types.number
          parent_post_id: nil
          user_id: current_user.id
          category_id: topic.category_id
          topic_id: topic.id
          body: "Hello from my pending post"
          body_format: Posts.body_formats.html
          status: PendingPosts.statuses.pending
          reason: PendingPosts.reasons.manual

          created_at: types.string
          updated_at: types.string
        }) pending_post

        topic\refresh!

        assert types.partial({
          posts_count: 0
          root_posts_count: 0
          last_post_id: types.nil
        }) topic

        assert types.shape({
          types.partial {
            object_id: pending_post.id
            object_type: ActivityLogs.object_types.pending_post
            action: ActivityLogs.actions.pending_post.create_post
            data: types.shape {
              topic_id: pending_post.topic_id
              category_id: pending_post.category_id
            }
          }
        }), ActivityLogs\select!

        assert pending_post\get_activity_log_create!

      it "creates pending post body_format", ->
        pending_post = new_pending_post {
          topic_id: topic.id
          "post[body]": "  Hello from my pending post  "
          "post[body_format]": "markdown"
        }

        assert types.partial({
          body_format: Posts.body_formats.markdown
        }) pending_post

      it "creates pending post with parent_post", ->
        post = factory.Posts topic_id: topic.id

        pending_post = new_pending_post {
          topic_id: topic.id
          "post[body]": "  Hello from my pending post  "
          parent_post_id: post.id
        }

        assert types.partial({
          parent_post_id: post.id
        }) pending_post

      it "force_pending", ->
        other_topic = factory.Topics!

        {:post, :pending_post} = in_request {
          post: {
            "post[body]": "Hello world"
          }
        }, =>
          @topic = other_topic
          @current_user = current_user
          @flow("posts")\new_post {
            force_pending: true
          }
          @

        assert.nil post, "Post should be set"
        assert.truthy pending_post, "pending_post should not be set"

      it "skips pending restriction if user is moderator", ->
        category\update user_id: current_user.id

        {:post, :pending_post} = new_post {
          topic_id: topic.id
          "post[body]": "  Hello from my pending post  "
        }

        assert.truthy post, "expected post to be created"
        assert.nil pending_post, "pending post should not be created"

  describe "delete topic", ->
    local topic

    before_each ->
      topic = factory.Topics user_id: current_user.id

    it "deletes topic", ->
      delete_topic { topic_id: topic.id }

      topic\refresh!
      assert.truthy topic.deleted
      assert.truthy topic.deleted_at

      assert.same -1, CommunityUsers\for_user(current_user).topics_count

      assert.same 1, ActivityLogs\count!
      logs = ActivityLogs\select!

      assert (types.shape {
        types.shape {
          user_id: current_user.id
          object_id: topic.id
          object_type: ActivityLogs.object_types.topic
          action: ActivityLogs.actions.topic.delete
        }, open: true
      }) logs


    it "doesn't allow unrelated user to delete topic", ->
      other_user = factory.Users!

      assert.has_error(
        -> delete_topic { topic_id: topic.id }, other_user
        { message: {"not allowed to edit"} }
      )

  describe "edit post", ->
    delete_post = (opts) ->
      in_request { post: opts }, =>
        @current_user = current_user
        PostsFlow(@)\delete_post!

    edit_post = (opts) ->
      in_request { post: opts }, =>
        @current_user = current_user
        PostsFlow(@)\edit_post!

    it "edits post", ->
      post = factory.Posts user_id: current_user.id

      edit_post {
        post_id: post.id
        -- TODO: test trimming  "post[body]": "the new body   \0"
        "post[body]": "the new body"
      }

      post\refresh!

      assert (types.shape {
        body: "the new body"
      }, open: true) post

      assert.same 1, ActivityLogs\count!
      logs = ActivityLogs\select!

      assert (types.shape {
        types.shape {
          user_id: current_user.id
          object_id: post.id
          object_type: ActivityLogs.object_types.post
          action: ActivityLogs.actions.post.edit
        }, open: true
      }) logs



    it "edit post and topic title", ->
      post = factory.Posts user_id: current_user.id

      edit_post {
        post_id: post.id
        "post[body]": "the new body"
        "post[title]": "the new title"
      }

      old_body = post.body

      post\refresh!
      assert.same "the new body", post.body
      assert.same "the new title", post\get_topic!.title
      assert.same "the-new-title", post\get_topic!.slug

      edit = unpack PostEdits\select!
      assert edit, "missing edit"
      assert.same current_user.id, edit.user_id
      assert.same post.id, edit.post_id
      assert.same old_body, edit.body_before

      assert.same 1, post.edits_count
      assert.truthy post.last_edited_at

    it "edits tags", ->
      post = factory.Posts user_id: current_user.id
      topic = post\get_topic!
      category = topic\get_category!

      factory.CategoryTags category_id: category.id, slug: "hello"
      factory.CategoryTags category_id: category.id, slug: "zone"

      edit_post {
        post_id: post.id
        "post[body]": "good stuff"
        "post[tags]": "hello,zone,woop"
      }

      topic\refresh!
      assert.same {"hello", "zone"}, topic.tags
      assert.same 2, #topic\get_tags!

    it "clear post tags when editing with empty tags", ->
      post = factory.Posts user_id: current_user.id
      topic = post\get_topic!
      category = topic\get_category!
      tag = factory.CategoryTags category_id: category.id

      topic\update tags: db.array { tag.slug }

      edit_post {
        post_id: post.id
        "post[body]": "good stuff"
        "post[tags]": ""
      }

      topic\refresh!
      assert.nil topic.tags

    it "edits post with reason", ->
      post = factory.Posts user_id: current_user.id

      edit_post {
        post_id: post.id
        "post[body]": "the newer body"
        "post[reason]": "changed something"
      }

      old_body = post.body
      post\refresh!
      assert.same "the newer body", post.body

      edit = unpack PostEdits\select!
      assert edit, "missing edit"
      assert.same current_user.id, edit.user_id
      assert.same post.id, edit.post_id
      assert.same old_body, edit.body_before
      assert.same "changed something", edit.reason

      assert.same 1, post.edits_count
      assert.truthy post.last_edited_at

    it "doesn't create post edit when editing with unchanged body", ->
      post = factory.Posts user_id: current_user.id

      edit_post {
        post_id: post.id
        "post[body]": post.body
        "post[reason]": "this will be ingored"
      }

      edit = unpack PostEdits\select!
      assert.falsy edit

      post\refresh!
      assert.same 0, post.edits_count
      assert.falsy post.last_edited_at

    describe "on_body_updated_callback", ->
      it "calls on_body_updated_callback when updating body", ->
        s = spy.on(Posts.__base, "on_body_updated_callback")

        post = factory.Posts user_id: current_user.id

        edit_post {
          post_id: post.id
          "post[body]": post.body .. " was changed!"
        }
        assert.spy(s, "on_body_updated_callback").was.called!

      it "doesn't call on_body_updated_callback when body is same", ->
        s = spy.on(Posts.__base, "on_body_updated_callback")

        post = factory.Posts user_id: current_user.id

        edit_post {
          post_id: post.id
          "post[body]": post.body
        }

        assert.spy(s, "on_body_updated_callback").was_not.called!

      it "calls on_body_updated_callback when updating title", ->
        s = spy.on(Posts.__base, "on_body_updated_callback")

        post = factory.Posts user_id: current_user.id

        edit_post {
          post_id: post.id
          "post[body]": post.body
          "post[title]": post\get_topic!.title .. " was changed!"
        }
        assert.spy(s, "on_body_updated_callback").was.called!

      it "doesn't call on_body_updated_callback when body & title are same", ->
        s = spy.on(Posts.__base, "on_body_updated_callback")

        post = factory.Posts user_id: current_user.id

        edit_post {
          post_id: post.id
          "post[body]": post.body
          "post[title]": post\get_topic!.title
        }

        assert.spy(s, "on_body_updated_callback").was_not.called!

    it "handles failure for invalid post id", ->
      assert.has_error(
        ->
          edit_post {
            post_id: 0
            "post[body]": "the new body"
            "post[title]": "the new title"
          }

        { message: {"invalid post"} }
      )

    it "doesn't let stranger edit post", ->
      post = factory.Posts!

      assert.has_error(
        ->
          edit_post {
            post_id: post.id
            "post[body]": "the new body"
            "post[title]": "the new title"
          }
        { message: {"not allowed to edit"} }
      )


    it "lets moderator edit post", ->
      post = factory.Posts!
      topic = post\get_topic!

      factory.Moderators {
        user_id: current_user.id
        object: topic\get_category!
      }

      edit_post {
        post_id: post.id
        "post[body]": "the new body"
        "post[title]": "the new title"
      }

      post\refresh!
      assert.same "the new body", post.body
      assert.same "the new title", post\get_topic!.title

    it "edits nth post in topic", ->
      topic = factory.Topics!
      post1 = factory.Posts topic_id: topic.id
      post2 = factory.Posts topic_id: topic.id, user_id: current_user.id

      edit_post {
        post_id: post2.id
        "post[body]": "the new body"
        "post[title]": "the new title"
      }

      post1\refresh!
      post2\refresh!
      before_title = topic.title
      topic\refresh!

      assert.same "the new body", post2.body
      assert.same before_title, topic.title

    it "softs delete post with replies", ->
      topic = factory.Topics user_id: current_user.id

      -- first post
      factory.Posts(user_id: current_user.id, topic_id: topic.id)

      -- creates second post
      post = factory.Posts {
        user_id: current_user.id
        topic_id: topic.id
      }

      factory.Posts topic_id: post.topic_id, parent_post_id: post.id

      topic\increment_participant current_user

      delete_post {
        post_id: post.id
      }

      post\refresh!
      assert.truthy post.deleted
      assert.truthy post.deleted_at

      -- -1 because we never incremented
      assert.same -1, CommunityUsers\for_user(current_user).posts_count

      tps = TopicParticipants\select "where topic_id = ?", topic.id
      assert.same 0, #tps

      topic\refresh!
      assert.same nil, topic.last_post_id

      assert.same 1, ActivityLogs\count!
      log = unpack ActivityLogs\select!
      assert.same current_user.id, log.user_id
      assert.same post.id, log.object_id
      assert.same ActivityLogs.object_types.post, log.object_type
      assert.same "delete", log\action_name!


    it "should hard delete post", ->
      topic = factory.Topics user_id: current_user.id

      -- first post
      factory.Posts(user_id: current_user.id, topic_id: topic.id)

      -- creates second post
      post = factory.Posts {
        user_id: current_user.id
        topic_id: topic.id
      }

      topic\increment_participant current_user

      delete_post {
        post_id: post.id
      }

      assert.same nil, (Posts\find post.id), "Expected post to be deleted"

      assert.same -1, CommunityUsers\for_user(current_user).posts_count

      tps = TopicParticipants\select "where topic_id = ?", topic.id
      assert.same 0, #tps

      topic\refresh!
      assert.same nil, topic.last_post_id

      assert.same 0, ActivityLogs\count!

    it "should delete primary post, deleting topic", ->
      post = factory.Posts {
        user_id: current_user.id
      }

      topic = post\get_topic!

      delete_post {
        post_id: post.id
      }

      topic\refresh!
      assert.truthy topic.deleted
      assert.truthy topic.deleted_at

      assert.same 1, ActivityLogs\count!
      log = unpack ActivityLogs\select!
      assert.same current_user.id, log.user_id
      assert.same topic.id, log.object_id
      assert.same ActivityLogs.object_types.topic, log.object_type
      assert.same "delete", log\action_name!


    it "should delete primary post of permanent topic, keep topic", ->
      topic = factory.Topics {
        user_id: current_user.id
        permanent: true
      }

      post = factory.Posts {
        topic_id: topic.id
        user_id: current_user.id
      }

      Topics\recount id: topic.id

      delete_post {
        post_id: post.id
      }

      topic\refresh!
      assert.falsy topic.deleted
      assert.same 0, topic.posts_count

    it "should not delete unrelated post", ->
      other_user = factory.Users!
      post = factory.Posts user_id: other_user.id

      assert.has_error(
        ->
          delete_post {
            post_id: post.id
          }

        { message: {"not allowed to edit"} }
      )

    it "should delete last post, refreshing topic on category and topic", ->
      category = factory.Categories!
      topic = factory.Topics(:category)

      p1 = factory.Posts(:topic)
      p2 = factory.Posts(:topic)

      other_topic = factory.Topics(:category)
      other_post = factory.Posts topic: other_topic

      post = factory.Posts(:topic, user_id: current_user.id)

      category\refresh!
      topic\refresh!

      assert.same topic.id, category.last_topic_id
      assert.same post.id, topic.last_post_id

      delete_post {
        post_id: post.id
      }

      category\refresh!
      topic\refresh!

      assert.same p2.id, topic.last_post_id
      assert.same topic.id, category.last_topic_id

    it "hard deletes post that has been soft deleted", ->
      category = factory.Categories user_id: current_user.id
      topic = factory.Topics(:category, permanent: true)
      post = factory.Posts :topic, deleted: true

      delete_post {
        post_id: post.id
      }

      assert.same {}, Posts\select!

