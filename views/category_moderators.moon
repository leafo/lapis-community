
class CategoryModerators extends require "widgets.base"
  inner_content: =>
    h2 ->
      a href: @url_for("category", category_id: @category.id), @category.name
      text " moderators"

    ul ->
      if @category\allowed_to_edit_moderators @current_user
        li ->
          a href: @url_for("category_new_moderator", category_id: @category.id), "New moderator"

    element "table", border: 1, ->
      thead ->
        tr ->
          td "Moderator"
          td "Accepted"
          td "Admin"
          td "Accept url"

      for mod in *@moderators
        user = mod\get_user!
        tr ->
          td ->
            a href: @url_for("user", user_id: user.id), user\name_for_display!

          td ->
            if mod.accepted
              raw "&#x2713;"

          td ->
            if mod.admin
              raw "&#x2713;"

          td ->
            return if mod.accepted
            a href: @url_for("category_accept_moderator", category_id: @category.id),
              "Link"

    unless next @moderators
      p ->
        em "There are no moderators"
