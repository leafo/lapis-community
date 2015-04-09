class NewPost extends require "widgets.base"
  inner_content: =>
    h1 "New topic"
    @render_errors!

    form method: "post", ->
      div ->
        label ->
          strong "Body"
          textarea name: "post[body]"

      button "Post"

