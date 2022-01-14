import in_request from require "spec.flow_helpers"

factory = require "spec.factory"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

import types from require "tableshape"

describe "browsing flow", ->
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
        get_category_preview = (user, params) ->
          in_request { get: params }, =>
            @current_user = user
            @flow("categories")\load_category!
            @flow("browsing")\preview_category_topics @category

        it "gets empty category", ->
          category = factory.Categories!
          topics = get_category_preview current_user, {
            category_id: category.id
          }

          assert.same {}, topics
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

          res = get_category_preview current_user, {
            category_id: category.id
          }

          assert.same 3, #res
          assert.same { t.id, true for t in *topics when not t.deleted },
            {t.id, true for t in *res}

          assert types.shape({
            types.partial {
              id: topics[4].id
            }
            types.partial {
              id: topics[3].id
            }
            types.partial {
              id: topics[1].id
            }
          }) res


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
        get_post_single = (user, params) ->
          in_request { get: params }, =>
            @current_user = user
            @flow("browsing")\post_single!
            @post

        it "gets post with no nested content", ->
          post = factory.Posts!

          res = get_post_single current_user, {
            post_id: post.id
          }

          assert.same post.id, res.id
          assert.same {}, res.children
          assert.truthy res.user
          assert.truthy res.topic

        it "gets post while logged out", ->
          post = factory.Posts!

          res = get_post_single nil, {
            post_id: post.id
          }

          assert types.partial({
            id: post.id
            children: types.shape {}

            -- check that fields were preloaded
            user: types.table
            topic: types.table
          }) res

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

          res = get_post_single current_user, {
            post_id: p.id
          }

          assert types.partial({
            id: p.id
            user: types.table
            topic: types.table

            children: types.shape {
              types.partial {
                id: pp1.id
                parent_post_id: p.id

                user: types.table
                topic: types.table
              }
              types.partial {
                id: pp2.id
                parent_post_id: p.id

                user: types.table
                topic: types.table
              }
            }

          }) res

        it "gets post without spam nested content", ->
          p = factory.Posts!
          topic = p\get_topic!
          topic\increment_from_post p

          c1 = factory.Posts status: "spam", topic_id: topic.id, parent_post_id: p.id
          topic\increment_from_post c1

          c2 = factory.Posts topic_id: topic.id, parent_post_id: p.id
          topic\increment_from_post c2

          res = get_post_single current_user, {
            post_id: p.id
          }

          assert.same 1, #res.children
          assert.same c2.id, res.children[1].id

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

          res = get_post_single current_user, {
            post_id: p.id
          }

          assert.same 2, #res.children
          assert.same {
            [c1.id]: true
            [c2.id]: true
          }, {c.id, true for c in *res.children}

      describe "category", ->
        get_category_single = (user, params) ->
          in_request { get: params }, =>
            @current_user = user
            @flow("browsing")\category_single!
            @category

        it "gets empty category", ->
          category = factory.Categories!

          res = get_category_single current_user, {
            category_id: category.id
          }

          assert types.partial({
            id: category.id
            children: types.shape {}
          }) res

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

          res = get_category_single current_user, {
            category_id: category.id
          }

          children = res.children

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

