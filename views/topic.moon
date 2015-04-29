class Topic extends require "widgets.base"
  inner_content: =>
    if @topic.category_id
      a href: @url_for("category", category_id: @topic\get_category!.id), @topic\get_category!.name

    h1 @topic.title

    p ->
      strong "Post count"
      text " "
      text @topic.posts_count

    ul ->
      a href: @url_for("new_post", topic_id: @topic.id), "Reply"


    @pagination!
    hr!

    for post in *@posts
      continue if post.deleted

      div ->
        strong post.user\name_for_display!
        text " "
        em post.created_at
        em " (#{post.id})"

        if post.edits_count > 0
          em " (#{post.edits_count} edits)"

        em " (+#{post.up_votes_count})"
        em " (-#{post.down_votes_count})"

      p post.body

      if post\allowed_to_edit @current_user
        p ->
          a href: @url_for("edit_post", post_id: post.id), "Edit"
          raw " &middot; "
          a href: @url_for("delete_post", post_id: post.id), "Delete"

      if @current_user
        p ->
          form action: @url_for("vote_post", post_id: post.id), method: "post", ->
            button value: "up", name: "direction", "Upvote"
            raw " &middot; "
            button value: "down", name: "direction", "Downvote"

            if vote = post.post_vote
              text " You voted #{vote\name!}"
              raw " &middot; "
              button value: "remove", name: "action", "Remove"

      hr!

    @pagination!


  pagination: =>
    topic_opts = { topic_id: @topic.id }

    if @after
      a {
        href: @url_for "topic", topic_opts, {
          after: @after
        }
        "Next page"
      }

    text " "

    if @before
      a {
        href: @url_for "topic", topic_opts, {
          before: @before
        }
        "Previous page"
      }

