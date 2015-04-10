
class CategoryNewMember extends require "widgets.base"
  inner_content: =>
    p ->
      a href: @url_for("category_members", category_id: @category.id),
        "Return to members"

    h2 "New member"
    @render_errors!

    form method: "post", ->
      div ->
        label ->
          strong "Username"
          input type: "text", name: "username"

      button "Invite user"


