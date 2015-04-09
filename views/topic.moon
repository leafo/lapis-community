class Topic extends require "widgets.base"
  inner_content: =>
    if @topic.category_id
      a href: @url_for("category", category_id: @topic\get_category!.id), @topic\get_category!.name

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
          a href: @url_for("edit_post", post_id: post.id), "Edit"
          text " . "
          a href: @url_for("delete_post", post_id: post.id), "Delete"

      hr!

