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
          td "L"
          td "S"
          td "Title"
          td "Poster"
          td "Posts"
          td "Posted"
          td "Last post"

      for topic in *@topics
        tr ->
          td ->
            if topic.locked
              raw "&#x2713;"

          td ->
            if topic.sticky
              raw "&#x2713;"

          td ->
            a href: @url_for("topic", topic_id: topic.id), topic.title

          td ->
            a href: @url_for("user", user_id: topic.user.id), topic.user\name_for_display!

          td tostring topic.posts_count

          td topic.created_at
          td topic.last_post_at

