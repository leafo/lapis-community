
class CategoryNewModerator extends require "widgets.base"
  inner_content: =>
    p ->
      a href: @url_for("category_moderators", category_id: @category.id),
        "Return to moderators"

    h2 "New moderator"
    @render_errors!

    form method: "post", ->
      div ->
        label ->
          strong "Username"
          input type: "text", name: "username"

      button "Invite user"


