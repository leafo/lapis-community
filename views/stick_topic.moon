class StickTopic extends require "widgets.base"
  inner_content: =>
    p ->
      text "Stick topic "
      a href: @url_for("topic", topic_id: @topic.id), @topic.title
      text "?"

    form method: "post", ->
      label ->
        strong "Reason"
        textarea name: "reason", placeholder: "optional, will be shown on top of topic"

      br!

      button "Stick topic"

