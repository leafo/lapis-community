Posts = require "widgets.posts"

class Post extends require "widgets.base"
  inner_content: =>
    widget Posts posts: { @post }
