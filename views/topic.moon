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
      li ->
        a href: @url_for("new_post", topic_id: @topic.id), "Reply"

      if @topic\allowed_to_moderate @current_user
        li ->
          a href: @url_for("lock_topic", topic_id: @topic.id), "Lock"

        li ->
          a href: @url_for("stick_topic", topic_id: @topic.id), "Stick"

    @pagination!
    hr!

    for post in *@posts
      @render_post post

    @pagination!

  render_post: (post) =>
    if post.deleted
      div class: "post deleted", ->
        em "This post has been deleted"
    else
      div class: "post", ->
        u "##{post.post_number}"
        text " "

        strong post.user\name_for_display!
        text " "
        em post.created_at
        em " (#{post.id})"

        if post.parent_post_id
          em " (parent: #{post.parent_post_id})"

        if post.edits_count > 0
          em " (#{post.edits_count} edits)"

        em " (+#{post.up_votes_count})"
        em " (-#{post.down_votes_count})"

      p post.body

      fieldset ->
        legend "Post tools"
        if post\allowed_to_edit @current_user
          p ->
            a href: @url_for("edit_post", post_id: post.id), "Edit"
            raw " &middot; "
            a href: @url_for("delete_post", post_id: post.id), "Delete"

        if @current_user
          p ->
            a href: @url_for("reply_post", post_id: post.id), "Reply"

            form action: @url_for("vote_object", object_type: "post", object_id: post.id), method: "post", ->
              button value: "up", name: "direction", "Upvote"
              raw " &middot; "
              button value: "down", name: "direction", "Downvote"

              if vote = post.vote
                text " You voted #{vote\name!}"
                raw " &middot; "
                button value: "remove", name: "action", "Remove"

    if post.children and post.children[1]
      blockquote ->
        for child in *post.children
          @render_post child

    hr!


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

