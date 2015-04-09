
class DeletePost extends require "widgets.base"
  inner_content: =>
    h2 "Delete post from #{@topic.title}"

    form method: "post", ->
      button "Delete"

    a href: @url_for("topic", topic_id: @topic.id), "Return to topic"


