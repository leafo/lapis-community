

class CategoryAcceptModerator extends require "widgets.base"
  inner_content: =>
    h2 ->
      text "Accept moderator position for "
      a href: @url_for("category", category_id: @category.id),
        @category.name

    form method: "post", ->
      button "Accept"

    p "Don't want to accept? Just ignore this page"

