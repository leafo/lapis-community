class CategoryAcceptMember extends require "widgets.base"
  inner_content: =>
    h2 ->
      text "Join the community "

      a href: @url_for("category", category_id: @category.id),
        @category.title

    form method: "post", ->
      button "Accept"

    p "Don't want to accept? Just ignore this page"

