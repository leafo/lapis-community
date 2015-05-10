html = require "lapis.html"
class Layout extends html.Widget
  content: =>
    html_5 ->
      head -> title @title or "Community test"

      body ->
        div ->
          text "Logged in as: #{@current_user and @current_user.username}"


          text " - "
          a href: @url_for("index"), "Home"

        hr!

        @content_for "inner"

