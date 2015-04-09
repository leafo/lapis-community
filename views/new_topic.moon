import Categories from require "models"

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

      button "New topic"
