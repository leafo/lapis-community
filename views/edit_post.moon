class EditPost extends require "widgets.base"
  inner_content: =>
    h1 ->
      if @editing
        text "Edit post"
      else
        text "New post"

    @render_errors!

    form method: "post", ->
      div ->
        label ->
          strong "Body"
          textarea name: "post[body]", value: @post and @post.body

      button ->
        if @editing
          text "Save"
        else
          text "Post"

