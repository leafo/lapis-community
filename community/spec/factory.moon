models = require "community.models"
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

-- use the Users factory in the current project
Users = (...)->
  require("spec.factory").Users ...

CommunityUsers = (opts={}) ->
  opts.user_id or= Users!.id
  assert models.CommunityUsers\create opts

Categories = (opts={}) ->
  opts.title or= "Category #{next_counter "category"}"
  assert models.Categories\create opts

Topics = (opts={}) ->
  local category
  if opts.category == false
    opts.category = nil
  elseif opts.category
    category = opts.category
    opts.category_id = category.id
    opts.category = nil
  else
    opts.category_id or= Categories!.id

  opts.user_id or= Users!.id
  opts.title or= "Topic #{next_counter "topic"}"

  with topic = assert models.Topics\create opts
    topic.category = category
    if category
      category\increment_from_topic topic

Posts = (opts={}) ->
  local topic
  opts.user_id or= Users!.id
  if opts.topic
    topic = opts.topic
    opts.topic_id = topic.id
    opts.topic = nil
  else
    opts.topic_id or= Topics(user_id: opts.user_id).id

  opts.body or= "Post #{next_counter "post"} body"

  with post = assert models.Posts\create opts
    post.topic = topic
    if topic
      topic\increment_from_post post

Votes = (opts={}) ->
  opts.positive = true if opts.positive == nil

  opts.user_id or= Users!.id

  opts.object or= Posts {
    [opts.positive and "up_votes_count" or "down_votes_count"]: 1
  }

  assert models.Votes\create opts

Moderators = (opts={}) ->
  opts.user_id or= Users!.id

  unless opts.object
    opts.object = Categories!

  opts.accepted = true if opts.accepted == nil
  assert models.Moderators\create opts

PostReports = (opts={}) ->
  if opts.category_id
    assert not opts.post_id, "no post id please"
    topic = Topics category_id: opts.category_id
    post = Posts topic_id: topic.id
    opts.post_id = post.id
  else
    post = if opts.post_id
      models.Posts\find opts.post_id
    else
      with post = Posts!
        opts.post_id = post.id

    opts.category_id or= post\get_topic!\get_category!.id

  opts.reason or= "offensive"
  opts.body or= "hello world"
  opts.user_id or= Users!.id

  assert models.PostReports\create opts

CategoryMembers = (opts={}) ->
  opts.user_id or= Users!.id
  opts.category_id or= Categories!.id
  opts.accepted = true if opts.accepted == nil
  assert models.CategoryMembers\create opts

Blocks = (opts={}) ->
  opts.blocking_user_id or= Users!.id
  opts.blocked_user_id or= Users!.id
  assert models.Blocks\create opts

Bans = (opts={}) ->
  opts.object or= Categories!
  opts.banned_user_id or= Users!.id
  opts.reason or= "this user is banned"
  opts.banning_user_id or= Users!.id
  assert models.Bans\create opts

CategoryGroups = (opts={}) ->
  opts.title or= "Category group #{next_counter "category-group"}"
  assert models.CategoryGroups\create opts

Bookmarks = (opts={}) ->
  opts.object_type or= "topic"
  opts.object_id or= Topics!.id
  opts.user_id or= Users!.id
  assert models.Bookmarks\create opts

PendingPosts = (opts={}) ->
  unless opts.topic_id
    topic = Topics category_id: opts.category_id
    opts.topic_id = topic.id
    opts.category_id = topic.category_id

  opts.user_id or= Users!.id
  opts.body or= "Pending post #{next_counter "post"} body"
  assert models.PendingPosts\create opts

CategoryTags = (opts={}) ->
  opts.category_id or= Categories!.id
  opts.label or= "Some tag #{next_counter "tag"}"
  assert models.CategoryTags\create opts


{ :next_counter, :next_email,
  :Categories, :Topics, :Posts, :Votes, :Moderators, :PostReports,
  :CategoryMembers, :Blocks, :Bans, :CategoryGroups, :Bookmarks,
  :CommunityUsers, :PendingPosts, :CategoryTags }
