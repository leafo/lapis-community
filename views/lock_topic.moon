class LockTopic extends require "widgets.base"
  inner_content: =>
    p ->
      text "Lock topic "
      a href: @url_for("topic", topic_id: @topic.id), @topic.title
      text "?"

    form method: "post", ->
      label ->
        strong "Reason"
        textarea name: "reason"

      br!

      button "Lock topic"

