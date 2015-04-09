class Topic extends require "widgets.base"
  inner_content: =>
    h1 @topic.title

    ul ->
      a href: @url_for("new_post", topic_id: @topic.id), "Reply"

    for post in *@posts
      continue if post.deleted
      div ->
        strong post.user\name_for_display!
        text " "
        em post.created_at

      q post.body

      if post\allowed_to_edit @current_user
        div ->
          a href: "", "Edit"


