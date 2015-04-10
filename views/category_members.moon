class CategoryMembers extends require "widgets.base"

  inner_content: =>
    h2 ->
      a href: @url_for("category", category_id: @category.id), @category.name
      text " members"

    ul ->
      if @category\allowed_to_edit_members @current_user
        li ->
          a href: @url_for("category_new_member", category_id: @category.id), "Add member"


    element "table", border: 1, ->
      thead ->
        tr ->
          td "Member"
          td "Accepted"
          td "Accept url"
          td "Remove"

      for member in *@members
        user = member\get_user!
        @dump member

        tr ->
          td ->
            a href: @url_for("user", user_id: user.id), user\name_for_display!

          td ->
            if member.accepted
              raw "&#x2713;"

          td ->
            return if member.accepted
            a href: @url_for("category_accept_member", category_id: @category.id),
              "Link"

          td ->
            form {
              action: @url_for "category_remove_member", category_id: @category.id, user_id: user.id
              method: "post"
            }, ->
              button "Remove"
