class Category extends require "widgets.base"
  inner_content: =>
    h1 @category.name
    if @user
      p ->
        text "Created by "
        a href: @url_for("user", user_id: @user.id), @user\name_for_display!

    ul ->
      li ->
        a href: @url_for("new_topic", category_id: @category.id), "New topic"

      if @category\allowed_to_edit @current_user
        li ->
          a href: @url_for("edit_category", category_id: @category.id), "Edit category"

      if @category\allowed_to_moderate @current_user
        li ->
          a href: @url_for("category_moderators", category_id: @category.id), "Moderators"
        li ->
          a href: @url_for("category_members", category_id: @category.id), "Members"

    h3 "Topics"

    p ->
      strong "Count"
      text " "
      text @category.topics_count


    if @sticky_topics and next @sticky_topics
      @render_topics @sticky_topics

    @render_topics @topics

  render_topics: (topics) =>
    element "table", border: "1", ->
      thead ->
        tr ->
          td "L"
          td "S"
          td "id"
          td "Title"
          td "Poster"
          td "Posts"
          td "Posted"
          td "Last post"

      for topic in *topics
        tr ->
          td ->
            if topic.locked
              raw "&#x2713;"

          td ->
            if topic.sticky
              raw "&#x2713;"

          td topic.id

          td ->
            text "(#{topic.category_order}) "

            a href: @url_for("topic", topic_id: topic.id), topic.title

          td ->
            a href: @url_for("user", user_id: topic.user.id), topic.user\name_for_display!

          td tostring topic.posts_count

          td topic.created_at
          td topic.last_post_at


    p ->
      cat_opts = {category_id: @category.id }

      if @before
        a {
          href: @url_for "category", cat_opts, {
            before: @before
          }
          "Next page"
        }

        text " "

      if @after
        a {
          href: @url_for "category", cat_opts, {
            after: @after
          }
          "Previous page"
        }

        text " "

        a {
          href: @url_for "category", cat_opts
          "First page"
        }

        text " "



