Posts = require "widgets.posts"

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

    widget Posts!

    @pagination!

  pagination: =>
    topic_opts = { topic_id: @topic.id }

    if @next_page
      a {
        href: @url_for "topic", topic_opts, @next_page
        "Next page"
      }

    text " "

    if @prev_page
      a {
        href: @url_for "topic", topic_opts, @prev_page
        "Previous page"
      }


  moderation_log_data: (log) =>
    return unless log
    log_user = log\get_user!
    p ->
      em "By #{log_user\name_for_display!} on #{log.created_at}"
      if log.reason
        em ": #{log.reason}"

