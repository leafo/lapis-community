import Categories from require "community.models"

class EditCategory extends require "widgets.base"
  inner_content: =>
    h1 ->
      if @editing
        text "Editing category: #{@category.name}"
      else
        text "New category"

    @render_errors!

    form method: "post", ->
      div ->
        label ->
          strong "Title"
          input type: "text", name: "category[name]", value: @category and @category.name

      strong "Membership type"

      for mtype in *Categories.membership_types
        div ->
          label ->
            input {
              type: "radio"
              name: "category[membership_type]"
              value: mtype
              checked: (@category and @category.membership_type == Categories.membership_types[mtype]) and "checked" or nil
            }

            text " "
            text mtype

      button ->
        if @editing
          text "Save"
        else
          text "New category"


