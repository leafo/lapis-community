import Categories from require "community.models"

class EditCategory extends require "widgets.base"
  inner_content: =>
    h1 ->
      if @editing
        text "Editing category: #{@category.title}"
      else
        text "New category"

    @render_errors!

    form method: "post", ->
      div ->
        label ->
          strong "Title"
          input type: "text", name: "category[title]", value: @category and @category.title

      div ->
        label ->
          strong "Short description"
          input type: "text", name: "category[short_description]", value: @category and @category.short_description

      div ->
        label ->
          strong "Description"
          textarea name: "category[description]", @category and @category.description

      strong "Membership type"

      @radio_buttons "category[membership_type]",
        Categories.membership_types,
        @category and @category\get_membership_type!

      strong "Voting type"
      @radio_buttons "category[voting_type]",
        Categories.voting_types,
        @category and @category\get_voting_type!

      button ->
        if @editing
          text "Save"
        else
          text "New category"

  radio_buttons: (name, enum, val) =>
    for key in *enum
      div ->
        label ->
          input {
            type: "radio"
            name: name
            value: key
            checked: enum[key] == val and "checked" or nil
          }

          text " #{key}"
