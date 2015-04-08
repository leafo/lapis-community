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

  [category: "/category/:category_id"]: capture_errors_json =>
    Browsing = require "community.flows.browsing"
    @topics = Browsing(@)\category_topics!
    render: true

  [index: "/"]: =>
    import Categories from require "models"
    @categories = Categories\select!
    render: true

