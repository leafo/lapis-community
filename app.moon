lapis = require "lapis"

import respond_to, capture_errors, capture_errors_json,
  assert_error from require "lapis.application"

import assert_valid from require "lapis.validate"

class extends lapis.Application
  @before_filter =>
    if id = @session.user_id
      import Users from require "models"
      @current_user = Users\find(:id)

  [register: "/register"]: respond_to {
    GET: =>
      render: true

    POST: capture_errors =>
      import Users from require "models"

      assert_valid @params, {
        {"username", exists: true}
      }

      user = Users\create {
        username: @params.username
      }

      @session.user_id = user.id
      redirect_to: @url_for "index"
  }

  [login: "/login"]: respond_to {
    GET: =>
      render: true

    POST: capture_errors =>
      import Users from require "models"
      assert_valid @params, {
        {"username", exists: true}
      }

      assert_error Users\find(username: @params.username), "invalid user"
  }

  [new_category: "/new-category"]: respond_to {
    GET: => render: true

    POST: capture_errors =>
      CategoriesFlow = require "community.flows.categories"
      CategoriesFlow(@)\new_category!

      redirect_to: @url_for "index"
  }

  [new_topic: "/category/:category_id/new-topic"]: capture_errors respond_to {
    before_filter: =>
      CategoriesFlow = require "community.flows.categories"
      CategoriesFlow(@)\load_category!

    GET:  =>
      render: true

    POST:  =>
      TopicsFlow = require "community.flows.topics"
      TopicsFlow(@)\new_topic!
      redirect_to: @url_for "category", category_id: @category.id
  }

  [new_post: "/topic/:topic_id/new-post"]: capture_errors respond_to {
    GET: =>
      render: true

    POST: =>
      PostsFlow = require "community.flows.posts"
      PostsFlow(@)\new_post!
      redirect_to: @url_for "topic", topic_id: @topic.id
  }

  [edit_post: "/post/:post_id/edit"]: respond_to {
    before: =>
      @editing = true

    GET: =>
      render: true

    POST: =>
  }

  [delete_post: "/post/:post_id/delete"]: respond_to {
    GET: =>
      render: true

    POST: =>
  }

  [category: "/category/:category_id"]: capture_errors_json =>
    BrowsingFlow = require "community.flows.browsing"
    @topics = BrowsingFlow(@)\category_topics!
    render: true

  [topic: "/topic/:topic_id"]: capture_errors_json =>
    BrowsingFlow = require "community.flows.browsing"
    @posts = BrowsingFlow(@)\topic_posts!
    render: true

  [index: "/"]: =>
    import Categories from require "models"
    @categories = Categories\select!
    render: true

