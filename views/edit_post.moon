class EditPost extends require "widgets.base"
  inner_content: =>
    if @topic
      p ->
        a href: @url_for("topic", topic_id: @topic.id), "Return to topic"

    h1 ->
      if @editing
        text "Edit post"
      else
        if @parent_post
          text "Reply to post"
        else
          text "New post"

    @render_errors!

    form method: "post", ->
      if @parent_post
        input type: "hidden", name: "parent_post_id", value: @parent_post.id

      if @editing and @post\is_topic_post! and not @topic.permanent
        div ->
          label ->
            strong "Title"
            input type: "text", name: "post[title]", value: @topic and @topic.title

      div ->
        label ->
          strong "Body"
          textarea name: "post[body]", @post and @post.body or nil

      button ->
        if @editing
          text "Save"
        else
          text "Post"


    if @parent_post
      hr!
      h3 "Replying to"
      p @parent_post.body
      user = @parent_post\get_user!

      p ->
        em @parent_post.created_at

      p ->
        a href: @url_for("user", user_id: user.id), user\name_for_display!

