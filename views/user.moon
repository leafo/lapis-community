
class User extends require "widgets.base"
  inner_content: =>
    h1 "#{@user\name_for_display!}"

    element "table", border: 1, ->
      for k in *{"topics_count", "posts_count", "votes_count"}
        tr ->
          td -> strong k
          td @community_user[k]



