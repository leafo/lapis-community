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

local *

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

  assert models.Posts\create opts

PostVotes = (opts={}) ->
  opts.positive = true if opts.positive == nil

  opts.user_id or= Users!.id
  opts.post_id or= Posts({
    [opts.positive and "up_votes_count" or "down_votes_count"]: 1
  }).id

  assert models.PostVotes\create opts

CategoryModerators = (opts={}) ->
  opts.user_id or= Users!.id
  opts.category_id or= Categories!.id
  assert models.CategoryModerators\create opts

{ :next_counter, :next_email,
  :Users, :Categories, :Topics, :Posts, :PostVotes, :CategoryModerators }
