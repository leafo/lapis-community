import use_test_env from require "lapis.spec"
import in_request from require "spec.flow_helpers"

factory = require "spec.factory"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

import TestApp from require "spec.helpers"

import filter_bans from require "spec.helpers"

import Users from require "models"

import types from require "tableshape"

class BrowsingApp extends TestApp
  @before_filter =>
    @current_user = @params.current_user_id and assert Users\find @params.current_user_id
    Browsing = require "community.flows.browsing"
    @flow = Browsing @

  "/post": capture_errors_json =>
    @flow\post_single!
    filter_bans @post\get_topic!

    json: {
      success: true
      post: @post
    }

  "/category": capture_errors_json =>
    @flow\category_single!
    filter_bans @category

    json: {
      success: true
      category: @category
    }

  "/category-preview": capture_errors_json =>
    CategoriesFlow = require "community.flows.categories"
    CategoriesFlow(@)\load_category!

    json: {
      success: true
      topics: @flow\preview_category_topics @category
    }

describe "browsing flow", ->
  use_test_env!

  import Users from require "spec.models"
  import Categories, Topics, Posts, Votes,
    UserCategoryLastSeens, UserTopicLastSeens from require "spec.community_models"

  for logged_in in *{true, nil} -- false
    local current_user

    describe logged_in and "logged in" or "logged out", ->
      before_each ->
        current_user = factory.Users! if logged_in

      describe "topic posts", ->
        topic_posts = (params, opts) ->
          in_request { get: params }, =>
            @current_user = current_user
            @flow("browsing")\topic_posts opts
            { posts: @posts, next_page: @next_page, prev_page: @prev_page}

        it "errors with no topic id", ->
          assert.has_error(
            ->
              topic_posts {}
            {
              message: { "topic_id: expected integer" }
            }
          )

          assert.has_error(
            ->
              topic_posts { topic_id: "helfelfjew fwef"}
            {
              message: { "topic_id: expected integer" }
            }
          )

        it "get flat posts in topic", ->
          topic = factory.Topics!
          posts = for i=1,3
            post = factory.Posts topic_id: topic.id
            topic\increment_from_post post
            post

          res = topic_posts {
            topic_id:  topic.id
          }

          assert.same 3, #res.posts
          assert.same [p.id for p in *posts], [p.id for p in *res.posts]

        it "gets posts in reverse", ->
          topic = factory.Topics!
          posts = for i=1,3
            post = factory.Posts topic_id: topic.id
            topic\increment_from_post post
            post

          res = topic_posts {
            topic_id: topic.id
          }, {
            order: "desc"
          }

          assert.same 3, #res.posts, "number of posts"
          assert.same [posts[i].id for i=#posts,1,-1], [p.id for p in *res.posts]

        it "get paginated posts with after", ->
          topic = factory.Topics!
          posts = for i=1,3
            post = factory.Posts topic_id: topic.id
            topic\increment_from_post post
            post

          -- skip the first post
          res = topic_posts {
            topic_id: topic.id
            after: 1
          }

          assert.same 2, #res.posts, "number of posts"
          assert.same {posts[2].id, posts[3].id}, [p.id for p in *res.posts]

          -- empty since it points to the first page first page
          assert.same {}, res.prev_page, "prev_page"
          assert.nil res.next_page, "next_page"

        it "gets paginated posts with before", ->
          topic = factory.Topics!
          posts = for i=1,3
            post = factory.Posts topic_id: topic.id
            topic\increment_from_post post
            post

          res = topic_posts {
            topic_id: topic.id
            before: 2
          }

          assert.same 1, #res.posts
          assert.same {posts[1].id }, [p.id for p in *res.posts]

          assert.same { after: 1 }, res.next_page, "prev_page"
          assert.nil res.prev_page, "next_page"

        it "sets pagination on posts", ->
          limits = require "community.limits"
          topic = factory.Topics!

          for i=1,limits.POSTS_PER_PAGE
            p = factory.Posts topic_id: topic.id
            topic\increment_from_post p

          res = topic_posts topic_id: topic.id

          assert.nil res.next_page, "next_page"
          assert.nil res.prev_page, "prev_page"

          -- add one more to push it over the limit
          p = factory.Posts topic_id: topic.id
          topic\increment_from_post p

          res = topic_posts topic_id: topic.id

          assert.same { after: 20 }, res.next_page, "next_page"
          assert.nil res.prev_page, "prev_page"

          more_posts = for i=1,3
            pp = factory.Posts topic_id: topic.id
            topic\increment_from_post pp
            pp

          res = topic_posts {
            topic_id: topic.id
            after: res.next_page.after
          }

          assert.same {}, res.prev_page, "prev_page"
          assert.nil res.next_page, "next_page"

          assert.same 4, #res.posts, "number of posts"
          assert.same {
            p.id
            more_posts[1].id
            more_posts[2].id
            more_posts[3].id
          }, [p.id for p in *res.posts]


        it "sets blank pagination on posts when there are archived in first position", ->
          topic = factory.Topics!
          posts = for i=1,2
            with post = factory.Posts topic_id: topic.id
              topic\increment_from_post post

          assert posts[1]\archive!

          res = topic_posts topic_id: topic.id
          assert.nil res.next_page, "next_page"
          assert.nil res.prev_page, "prev_page"

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

          res = topic_posts topic_id: topic.id

          assert.truthy res.posts

          flatten = (list, accum={}) ->
            return for p in *list
              {
                id: p.id
                children: p.children and flatten(p.children) or {}
              }

          nesting = flatten res.posts
          assert.same expected_nesting, nesting

        it "increments views", ->
          topic = factory.Topics!
          post = factory.Posts topic_id: topic.id
          topic\increment_from_post post

          res = topic_posts { topic_id: topic.id }
          assert.truthy res.posts

          topic\refresh!
          assert.same 1, topic.views_count, "views_count"

      describe "preview category topics", ->
        it "gets empty category", ->
          category = factory.Categories!
          res = BrowsingApp\get current_user, "/category-preview", category_id: category.id
          assert.truthy res.success
          assert.same 0, #res.topics
          assert.same 0, UserCategoryLastSeens\count!

        it "gets some topics", ->
          local category, topics
          for i=1,2
            category = factory.Categories!
            topics = for i=1,4
              with topic = factory.Topics category_id: category.id
                category\increment_from_topic topic
                post = factory.Posts topic_id: topic.id
                topic\increment_from_post post


          topics[2]\delete!
          topics[2]\refresh!

          res = BrowsingApp\get current_user, "/category-preview", category_id: category.id

          assert.truthy res.success
          assert.same 3, #res.topics
          assert.same { t.id, true for t in *topics when not t.deleted },
            {t.id, true for t in *res.topics}


      describe "category topics", ->
        category_topics = (user, params) ->
          params or= {}
          unless params.category_id
            params.category_id = factory.Categories!.id

          res = in_request { get: params }, =>
            @current_user = user
            @flow("browsing")\category_topics!
            { @topics, @next_page, @prev_page }

          unpack res

        sticky_category_topics = (user, params) ->
          params or= {}
          unless params.category_id
            params.category_id = factory.Categories!.id

          in_request { get: params }, =>
            @current_user = user
            @flow("browsing")\sticky_category_topics!
            @sticky_topics

        it "gets empty category", ->
          topics, next_page, prev_page = category_topics!

          assert.same {}, topics
          assert.same nil, next_page
          assert.same nil, prev_page
          assert.same 0, UserCategoryLastSeens\count!

        it "gets empty sticky topics", ->
          topics = sticky_category_topics!
          assert.same {}, topics

        it "gets some topics", ->
          category = factory.Categories!

          topics = for i=1,4
            with topic = factory.Topics category_id: category.id
              category\increment_from_topic topic

          result_topics, next_page, prev_page = category_topics current_user, {
            category_id: category.id
          }

          assert.same 4, #result_topics
          assert.nil next_page
          assert.nil prev_page

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

          result_topics, next_page, prev_page = sticky_category_topics nil, {
            category_id: category.id
          }

          assert types.shape({
            types.shape {
              id: topics[1].id
            }, open: true
          }) result_topics

        it "archived & hidden topics are exluded by default", ->
          category = factory.Categories!
          topics = for i=1,4
            with topic = factory.Topics category_id: category.id
              category\increment_from_topic topic

          topics[1]\archive!
          topics[3]\hide!

          result_topics = category_topics current_user, {
            category_id: category.id
          }

          assert types.shape({
            types.shape {
              id: topics[4].id
            }, open: true
            types.shape {
              id: topics[2].id
            }, open: true
          }) result_topics

        it "shows only hidden topics", ->
          category = factory.Categories!
          topics = for i=1,4
            with topic = factory.Topics category_id: category.id
              category\increment_from_topic topic

          topics[2]\archive!
          topics[3]\hide!

          result_topics = category_topics current_user, {
            category_id: category.id
            status: "hidden"
          }

          assert types.shape({
            types.shape {
              id: topics[3].id
            }, open: true
          }) result_topics


        it "only shows archived topics", ->
          category = factory.Categories!
          topics = for i=1,4
            with topic = factory.Topics category_id: category.id
              category\increment_from_topic topic

          topics[2]\archive!
          topics[3]\hide!

          result_topics = category_topics current_user, {
            category_id: category.id
            status: "archived"
          }

          assert types.shape({
            types.shape {
              id: topics[2].id
            }, open: true
          }) result_topics

        it "sets pagination for category", ->
          category = factory.Categories!
          limits = require "community.limits"

          for i=1,limits.TOPICS_PER_PAGE + 1
            topic = factory.Topics category_id: category.id
            category\increment_from_topic topic

          result_topics, next_page, prev_page = category_topics current_user, {
            category_id: category.id
          }

          assert.same 20, #result_topics
          assert.same { before: 2 }, next_page
          assert.same nil, prev_page

          result_page_2, next_page, prev_page = category_topics current_user, {
            category_id: category.id
            before: next_page.before
          }

          assert.same 1, #result_page_2
          assert.same nil, next_page
          assert.same {after: 1}, prev_page

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

