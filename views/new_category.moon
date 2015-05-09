import Categories from require "community.models"

class NewCategory extends require "widgets.base"
  inner_content: =>
    h1 "New category"
    @render_errors!

    form method: "post", ->
      div ->
        label ->
          strong "Title"
          input type: "text", name: "category[name]"

      strong "Membership type"
      for mtype in *Categories.membership_types
        div ->
          label ->
            input {
              type: "radio"
              name: "category[membership_type]"
              value: mtype
            }

            text " "
            text mtype

      button "New category"


