
import Categories from require "models"

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

    h2 "Categories"
    element "table", border: 1, ->
      thead ->
        tr ->
          td "Category"
          td "Type"
          td "Topics count"
          td "Creator"

      for cat in *@categories
        tr ->
          td ->
            a href: @url_for("category", category_id: cat.id), cat.name

          td Categories.membership_types[cat.membership_type]
          td cat.topics_count
          td ->
            if user = cat\get_user!
              a href: @url_for("user", user_id: user.id), user\name_for_display!

    unless next @categories
      p -> em "There are no categories"

