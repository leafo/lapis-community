lapis = require "lapis"

import respond_to, capture_errors, assert_error from require "lapis.application"

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

  [index: "/"]: =>
    render: true

