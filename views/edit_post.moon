class EditPost extends require "widgets.base"
  inner_content: =>
    if @topic
      p ->
        a href: @url_for("topic", topic_id: @topic.id), "Return to topic"

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
          textarea name: "post[body]", @post and @post.body or nil

      button ->
        if @editing
          text "Save"
        else
          text "Post"

