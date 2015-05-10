class NewTopic extends require "widgets.base"
  inner_content: =>
    h1 "New topic"
    @render_errors!

    form method: "post", ->
      div ->
        label ->
          strong "Title"
          input type: "text", name: "topic[title]"

      div ->
        label ->
          strong "Body"
          textarea name: "topic[body]"

      if @category\allowed_to_moderate @current_user
        div ->
          label ->
            input type: "checkbox", name: "topic[sticky]"
            text " Sticky"

        div ->
          label ->
            input type: "checkbox", name: "topic[locked]"
            text " Locked"

      button "New topic"
