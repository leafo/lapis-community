class CategoryMembers extends require "widgets.base"
  inner_content: =>
    h2 ->
      a href: @url_for("category", category_id: @category.id), @category.name
      text " members"
