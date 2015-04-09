class Category extends require "widgets.base"
  inner_content: =>
    h1 @category.name

    ul ->
      li ->
        a href: @url_for("new_topic", category_id: @category.id), "New topic"

    h3 "Topics"
    element "table", border: "1", ->
      thead ->
        tr ->
          td "Title"

      for topic in *@topics
        tr ->
          td ->
            a href: @url_for("topic", topic_id: topic.id), topic.title

