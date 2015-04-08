
class Index extends require "widgets.base"
  inner_content: =>
    h1 "Index"

    if @current_user
      p ->
        text "You are logged in as "
        strong @current_user\name_for_display!

    ul ->
      if @current_user
        li ->
          a href: @url_for("new_category"), "Create category"
      else
        li ->
          a href: @url_for("register"), "Register"

        li ->
          a href: @url_for("login"), "Login"

    if next @categories
      h2 "Categories"
      ul ->
        for cat in *@categories
          a href: @url_for("category", category_id: cat.id), cat.name

