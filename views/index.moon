
class Index extends require "widgets.base"
  inner_content: =>
    h1 "Index"

    if @current_user
      p ->
        text "You are logged in as "
        strong @current_user\name_for_display!

    ul ->
      unless @current_user
        li ->
          a href: @url_for("register"), "Register"

        li ->
          a href: @url_for("login"), "Login"

