-- TODO: move this to respetive category/topic specs
import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"
import in_request from require "spec.flow_helpers"

factory = require "spec.factory"

db = require "lapis.db"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

import TestApp from require "spec.helpers"

PostsFlow = require "community.flows.posts"

import Users from require "models"

import types from require "tableshape"

describe "posting flow", ->
  use_test_env!

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

  new_topic = (post) ->
    in_request { :post }, =>
      @current_user = current_user
      @flow("topics")\new_topic!

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
        posts_count: 0
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
          publishable: false
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
          message: {"your account is not authorized to post"}
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
          message: {"your account is not authorized to post"}
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



  describe "new post", ->
    local topic

    before_each ->
      -- note this isn't a full topic, it has no first post
      topic = factory.Topics!

    new_post = (post={}) ->
      in_request { :post }, =>
        @topic = topic
        @current_user = current_user
        @flow("posts")\new_post!
        @post or @pending_post

    it "errors with empty body", ->
      assert.has_error(
        ->
          new_post {
            "post[body]": ""
          }
        {
          message: {"body: expected text between 1 and 20480 characters"}
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
          publishable: false
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
          message: {"your account is not authorized to post"}
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
          message: {"your account is not authorized to post"}
        }
      )

    it "blocks posting with only_own", ->
      cu = CommunityUsers\for_user current_user
      cu\update {
        posting_permission: CommunityUsers.posting_permissions.only_own
      }

      assert.has_error(
        ->
          new_post {
            topic_id: topic.id
            "post[body]": "hello world"
          }

        {
          message: {"your account is not authorized to post"}
        }
      )

      assert.same 0, Posts\count!

      -- doesn't let them post in own topic
      topic\update {
        user_id: current_user.id
      }

      -- clear the memo cache
      topic = Topics\find topic.id

      new_post {
        topic_id: topic.id
        "post[body]": "hello world"
      }

    describe "parent_post_id", ->
      it "fails with invalid parent_post_id value", ->
        post = factory.Posts topic_id: topic.id

        assert.has_error(
          ->
            new_post {
              topic_id: topic.id
              parent_post_id: "cool"
              "post[body]": "This is a sub message"
            }

          { message: {"parent_post_id: expected integer then database id, or empty"} }
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

      it "posts a threaded post", ->
        post = factory.Posts topic_id: topic.id

        child_post = new_post {
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

      before_each ->
        category = topic\get_category!
        category\update {
          approval_type: Categories.approval_types.pending
        }

      new_pending_post = (opts) ->
        pending_post = new_post opts
        assert pending_post.__class == PendingPosts
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

          created_at: types.string
          updated_at: types.string
        }) pending_post

        topic\refresh!

        assert types.partial({
          posts_count: 0
          root_posts_count: 0
          last_post_id: types.nil
        }) topic

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
          publishable: false
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
          publishable: false
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

      assert.same nil, (Posts\find post.id)

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

