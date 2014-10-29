models = require "models"
db = require "lapis.db"

import Model from require "lapis.db.model"
import slugify from require "lapis.util"

next_counter = do
  counters = setmetatable {}, __index: => 1
  (name) ->
    with counters[name]
      counters[name] += 1

next_email = ->
  "me-#{next_counter "email"}@example.com"

Users = (opts={}) ->
  opts.username or= "user-#{next_counter "username"}"
  opts.email or= next_email!
  opts.password or= "my-password"
  assert models.Users\create opts

Categories = (opts={}) ->
  opts.name or= "category-#{next_counter "category"}"
  assert models.Categories\create opts

Topics = (opts={}) ->
  opts.category_id or= Categories!.id
  opts.user_id or= Users!.id
  opts.title or= "Topic #{next_counter "topic"}"

  assert models.Topics\create opts

Posts = (opts={}) ->
  opts.topic_id or= Topics!.id
  opts.user_id or= Users!.id
  opts.body or= "Post #{next_counter "post"} body"

{ :next_counter, :next_email,
  :Users, :Categories, :Topics, :Posts }
