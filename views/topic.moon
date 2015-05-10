class Topic extends require "widgets.base"
  inner_content: =>
    if @topic.category_id
      a href: @url_for("category", category_id: @topic\get_category!.id), @topic\get_category!.title

    h1 @topic.title

    p ->
      strong "Post count"
      text " "
      text @topic.posts_count

    if @topic.locked
      fieldset ->
        log = @topic\get_lock_log!
        p ->
          em "This topic is locked"

        @moderation_log_data log

        if @topic\allowed_to_moderate @current_user
          form action: @url_for("unlock_topic", topic_id: @topic.id), method: "post", ->
            button "Unlock"

    if @topic.sticky
      fieldset ->
        log = @topic\get_sticky_log!
        p ->
          em "This topic is sticky"

        @moderation_log_data log

        if @topic\allowed_to_moderate @current_user
          form action: @url_for("unstick_topic", topic_id: @topic.id), method: "post", ->
            button "Unstick"

    ul ->
      unless @topic.locked
        li ->
          a href: @url_for("new_post", topic_id: @topic.id), "Reply"

      if @topic\allowed_to_moderate @current_user
        unless @topic.locked
          li ->
            a href: @url_for("lock_topic", topic_id: @topic.id), "Lock"

        unless @topic.sticky
          li ->
            a href: @url_for("stick_topic", topic_id: @topic.id), "Stick"

    @pagination!
    hr!

    for post in *@posts
      @render_post post

    @pagination!

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


  moderation_log_data: (log) =>
    return unless log
    log_user = log\get_user!
    p ->
      em "By #{log_user\name_for_display!} on #{log.created_at}"
      if log.reason
        em ": #{log.reason}"

