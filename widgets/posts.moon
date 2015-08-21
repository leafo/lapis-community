
class Posts extends require "widgets.base"
  @needs: {
    "posts"
    "topic"
  }

  inner_content: =>
    for post in *@posts
      @render_post post

  render_post: (post) =>
    vote_types = @topic\available_vote_types!

    if post.deleted
      div class: "post deleted", ->
        em "This post has been deleted"
    elseif post.block
      div class: "post deleted", ->
        em "You have blocked this user (#{post.user\name_for_display!})"
        form action: @url_for("unblock_user", blocked_user_id: post.user_id), method: "post", ->
          button "Unblock"

    else
      div class: "post", ->
        u ->
          a href: @url_for("post", post_id: post.id), "##{post.post_number}"

        text " "

        strong post.user\name_for_display!
        text " "
        em post.created_at
        em " (#{post.id})"

        if post.parent_post_id
          em " (parent: #{post.parent_post_id})"

        if post.edits_count > 0
          em " (#{post.edits_count} edits)"

        if vote_types.up
          em " (+#{post.up_votes_count})"

        if vote_types.down
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

            form action: @url_for("block_user", blocked_user_id: post.user_id), method: "post", ->
              button "Block"

            form action: @url_for("vote_object", object_type: "post", object_id: post.id), method: "post", ->
              if vote_types.up
                button value: "up", name: "direction", "Upvote"

              if vote_types.up and vote_types.down
                raw " &middot; "

              if vote_types.down
                button value: "down", name: "direction", "Downvote"

              if vote = post.vote
                if vote_types[vote\name!]
                  text " You voted #{vote\name!}"
                  raw " &middot; "
                  button value: "remove", name: "action", "Remove"

    if post.children and post.children[1]
      blockquote ->
        for child in *post.children
          @render_post child

    hr!

