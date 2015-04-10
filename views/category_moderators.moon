
class CategoryModerators extends require "widgets.base"
  inner_content: =>
    h2 ->
      a href: @url_for("category", category_id: @category.id), @category.name
      text " moderators"

    ul ->
      li ->
        a href: @url_for("category_new_moderator", category_id: @category.id), "New moderator"

    element "table", border: 1, ->
      thead ->
        tr ->
          td "Moderator"

    unless next @moderators
      p ->
        em "There are no moderators"
