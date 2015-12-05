import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Categories, Topics, Posts, Votes, UserCategoryLastSeens, UserTopicLastSeens from require "community.models"

factory = require "spec.factory"

import mock_request from require "lapis.spec.request"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

import TestApp from require "spec.helpers"

class BrowsingApp extends TestApp
  @before_filter =>
    @current_user = @params.current_user_id and assert Users\find @params.current_user_id
    Browsing = require "community.flows.browsing"
    @flow = Browsing @

  "/post": capture_errors_json =>
    @flow\post_single!
    json: {
      success: true
      post: @post
    }

  "/category": capture_errors_json =>
    @flow\category_single!
    json: {
      success: true
      category: @category
    }

  "/topic-posts": capture_errors_json =>
    @flow\topic_posts {
      order: @params.order
    }

    json: {
      success: true
      posts: @posts
      next_page: @next_page
      prev_page: @prev_page
    }

  "/category-topics": capture_errors_json =>
    @flow\category_topics!
    json: {
      success: true
      topics: @topics
      next_page: @next_page
      prev_page: @prev_page
    }


  "/sticky-category-topics": capture_errors_json =>
    @flow\sticky_category_topics!
    json: {
      success: true
      sticky_topics: @sticky_topics
    }

describe "browsing flow", ->
  use_test_env!

  before_each ->
    truncate_tables Users, Categories, Topics, Posts, Votes, UserCategoryLastSeens, UserTopicLastSeens

  for logged_in in *{true, nil} -- false
    local current_user

    describe logged_in and "logged in" or "logged out", ->
      before_each ->
        current_user = factory.Users! if logged_in

      describe "topic posts", ->
        it "should error with no topic id", ->
          res = BrowsingApp\get current_user, "/topic-posts"
          assert.truthy res.errors
          assert.same {"topic_id must be an integer"}, res.errors

        it "get flat posts in topic", ->
          topic = factory.Topics!
          posts = for i=1,3
            post = factory.Posts topic_id: topic.id
            topic\increment_from_post post
            post

          res = BrowsingApp\get current_user, "/topic-posts", topic_id: topic.id
          assert.truthy res.success
          assert.same 3, #res.posts
          assert.same [p.id for p in *posts], [p.id for p in *res.posts]

        it "gets posts in reverse", ->
          topic = factory.Topics!
          posts = for i=1,3
            post = factory.Posts topic_id: topic.id
            topic\increment_from_post post
            post

          res = BrowsingApp\get current_user, "/topic-posts", {
            topic_id: topic.id
            order: "desc"
          }

          assert.truthy res.success
          assert.same 3, #res.posts
          assert.same [posts[i].id for i=#posts,1,-1], [p.id for p in *res.posts]

        it "should get paginated posts with after", ->
          topic = factory.Topics!
          for i=1,3
            post = factory.Posts topic_id: topic.id
            topic\increment_from_post post

          res = BrowsingApp\get current_user, "/topic-posts", {
            topic_id: topic.id
            after: 1
          }

          assert.truthy res.success
          assert.same 2, #res.posts

          -- empty since it's first page
          assert.same {}, res.prev_page

        it "should get paginated posts with before", ->
          topic = factory.Topics!
          for i=1,3
            post = factory.Posts topic_id: topic.id
            topic\increment_from_post post

          res = BrowsingApp\get current_user, "/topic-posts", {
            topic_id: topic.id
            before: 2
          }

          assert.truthy res.success
          assert.same 1, #res.posts

        it "sets pagination on posts", ->
          limits = require "community.limits"
          topic = factory.Topics!

          for i=1,limits.POSTS_PER_PAGE
            p = factory.Posts topic_id: topic.id
            topic\increment_from_post p

          res = BrowsingApp\get current_user, "/topic-posts", topic_id: topic.id

          assert.falsy res.next_page
          assert.falsy res.prev_page

          -- one more to push it over the limit
          p = factory.Posts topic_id: topic.id
          topic\increment_from_post p

          res = BrowsingApp\get current_user, "/topic-posts", topic_id: topic.id
          assert.same { after: 20 }, res.next_page
          assert.falsy res.prev_page


          for i=1,3
            p = factory.Posts topic_id: topic.id
            topic\increment_from_post p

          res = BrowsingApp\get current_user, "/topic-posts", {
            topic_id: topic.id
            after: res.next_page.after
          }

          assert.same {}, res.prev_page
          assert.nil res.next_page

          assert.same 4, #res.posts

        it "sets blank pagination on posts when there are archived in first position", ->
          topic = factory.Topics!
          posts = for i=1,2
            with post = factory.Posts topic_id: topic.id
              topic\increment_from_post post

          assert posts[1]\archive!

          res = BrowsingApp\get current_user, "/topic-posts", topic_id: topic.id
          assert.falsy res.next_page
          assert.falsy res.prev_page

        it "should get some nested posts", ->
          topic = factory.Topics!

          expected_nesting = {}

          for i=1,3
            p = factory.Posts topic_id: topic.id
            topic\increment_from_post p

            node = {id: p.id, children: {} }
            table.insert expected_nesting, node

            for i = 1,2
              pp = factory.Posts topic_id: topic.id, parent_post: p
              topic\increment_from_post pp
              inner_node = {id: pp.id, children: {}}
              table.insert node.children, inner_node

              ppp = factory.Posts topic_id: topic.id, parent_post: pp
              topic\increment_from_post ppp
              table.insert inner_node.children, {
                id: ppp.id, children: {}
              }

          res = BrowsingApp\get current_user, "/topic-posts", topic_id: topic.id

          assert.truthy res.posts
          flatten = (list, accum={}) ->
            return for p in *list
              {
                id: p.id
                children: p.children and flatten(p.children) or {}
              }

          nesting = flatten res.posts
          assert.same expected_nesting, nesting

      describe "category topics", ->
        it "gets empty category", ->
          category = factory.Categories!
          res = BrowsingApp\get current_user, "/category-topics", category_id: category.id
          assert.truthy res.success
          assert.same 0, #res.topics
          assert.same 0, UserCategoryLastSeens\count!

        it "gets empty sticky topics", ->
          category = factory.Categories!
          res = BrowsingApp\get current_user, "/sticky-category-topics", category_id: category.id
          assert.truthy res.success
          assert.same 0, #res.sticky_topics

        it "gets some topics", ->
          category = factory.Categories!

          topics = for i=1,4
            with topic = factory.Topics category_id: category.id
              category\increment_from_topic topic

          res = BrowsingApp\get current_user, "/category-topics", category_id: category.id

          assert.truthy res.success
          assert.same 4, #res.topics
          assert.falsy res.next_page
          assert.falsy res.prev_page

          last_seen, other = unpack UserCategoryLastSeens\select!
          assert.nil other

          last_topic = topics[4]
          last_topic\refresh!

          assert.same {
            category_id: category.id
            user_id: current_user.id
            topic_id: last_topic.id
            category_order: last_topic.category_order
          }, last_seen


        it "gets only sticky topics", ->
          category = factory.Categories!

          topics = for i=1,2
            with topic = factory.Topics category_id: category.id
              category\increment_from_topic topic

          topics[1]\update sticky: true

          res = BrowsingApp\get current_user, "/sticky-category-topics", category_id: category.id
          assert.truthy res.success
          assert.same 1, #res.sticky_topics
          assert.same topics[1].id, res.sticky_topics[1].id

        it "archived topics are exluded by default", ->
          category = factory.Categories!
          topics = for i=1,4
            with topic = factory.Topics category_id: category.id
              category\increment_from_topic topic

          topics[1]\archive!

          res = BrowsingApp\get current_user, "/category-topics", category_id: category.id
          assert.same 3, #res.topics
          ids = {t.id, true for t in *res.topics}
          assert.same {
            [topics[2].id]: true
            [topics[3].id]: true
            [topics[4].id]: true
          }, ids

        it "only shows archived topics", ->
          category = factory.Categories!
          topics = for i=1,4
            with topic = factory.Topics category_id: category.id
              category\increment_from_topic topic

          topics[2]\archive!

          res = BrowsingApp\get current_user, "/category-topics", {
            category_id: category.id
            status: "archived"
          }

          assert.same 1, #res.topics
          assert.same topics[2].id, res.topics[1].id

        it "sets pagination for category", ->
          category = factory.Categories!
          limits = require "community.limits"

          for i=1,limits.TOPICS_PER_PAGE + 1
            topic = factory.Topics category_id: category.id
            category\increment_from_topic topic

          res = BrowsingApp\get current_user, "/category-topics", category_id: category.id

          assert.truthy res.success
          assert.same 20, #res.topics
          assert.same {before: 2}, res.next_page
          assert.same nil, res.prev_page

          res = BrowsingApp\get current_user, "/category-topics", {
            category_id: category.id
            before: res.next_page.before
          }

          assert.truthy res.success
          assert.same 1, #res.topics
          assert.same nil, res.next_page
          assert.same {after: 1}, res.prev_page

      describe "post", ->
        it "gets post with no nested content", ->
          post = factory.Posts!

          res = BrowsingApp\get current_user, "/post", {
            post_id: post.id
          }

          assert.same post.id, res.post.id
          assert.same {}, res.post.children
          assert.truthy res.post.user
          assert.truthy res.post.topic

        it "gets post with nested content", ->
          p = factory.Posts!
          topic = p\get_topic!
          topic\increment_from_post p

          pp1 = factory.Posts topic_id: topic.id, parent_post: p
          topic\increment_from_post pp1
          pp2 = factory.Posts topic_id: topic.id, parent_post: p
          topic\increment_from_post pp2

          ppp1 = factory.Posts topic_id: topic.id, parent_post: pp1
          topic\increment_from_post ppp1

          res = BrowsingApp\get current_user, "/post", {
            post_id: p.id
          }

          assert.same p.id, res.post.id
          assert.truthy res.post.user
          assert.truthy res.post.topic

          assert.same {pp1.id, pp2.id}, [child.id for child in *res.post.children]

          for child in *res.post.children
            assert.same p.id, child.parent_post_id
            assert.truthy child.user
            assert.truthy child.topic

        it "gets post without spam nested content", ->
          p = factory.Posts!
          topic = p\get_topic!
          topic\increment_from_post p

          c1 = factory.Posts status: "spam", topic_id: topic.id, parent_post_id: p.id
          topic\increment_from_post c1

          c2 = factory.Posts topic_id: topic.id, parent_post_id: p.id
          topic\increment_from_post c2

          res = BrowsingApp\get current_user, "/post", {
            post_id: p.id
          }

          assert.same 1, #res.post.children
          assert.same c2.id, res.post.children[1].id

        it "shows archive children when viewing archived post", ->
          -- NOTE: this is currently impossible in practice since only root
          -- posts can be archived, but it's implemented like this for future
          -- proofing

          p = factory.Posts status: "archived"
          topic = p\get_topic!
          topic\increment_from_post p

          c1 = factory.Posts topic_id: topic.id, parent_post_id: p.id
          topic\increment_from_post c1

          c2 = factory.Posts status: "archived", topic_id: topic.id, parent_post_id: p.id
          topic\increment_from_post c2

          res = BrowsingApp\get current_user, "/post", {
            post_id: p.id
          }

          assert.same 2, #res.post.children
          assert.same {
            [c1.id]: true
            [c2.id]: true
          }, {c.id, true for c in *res.post.children}

      describe "category", ->
        it "gets empty category", ->
          category = factory.Categories!

          res = BrowsingApp\get current_user, "/category", {
            category_id: category.id
          }

          assert.same {}, res.category.children

        it "gets category with children preloaded", ->
          category = factory.Categories!

          a = factory.Categories parent_category_id: category.id
          b = factory.Categories parent_category_id: category.id

          category_topic = (cat) ->
            topic = factory.Topics category_id: cat.id
            post = factory.Posts topic_id: topic.id
            topic\increment_from_post post
            cat\increment_from_topic topic

            topic

          a_topic = category_topic a
          b_topic = category_topic b

          res = BrowsingApp\get current_user, "/category", {
            category_id: category.id
          }

          children = res.category.children

          assert.same 2, #children

          for child in *children
            assert.same category.id, child.parent_category_id

          -- see if we've preloaded everything
          assert.same a_topic.id, children[1].last_topic.id
          assert.same b_topic.id, children[2].last_topic.id

          assert.same a_topic.last_post_id, children[1].last_topic.last_post.id
          assert.same b_topic.last_post_id, children[2].last_topic.last_post.id

          assert.same a_topic\get_last_post!.user_id, children[1].last_topic.last_post.user.id
          assert.same b_topic\get_last_post!.user_id, children[2].last_topic.last_post.user.id

