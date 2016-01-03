local models = require("community.models")
local db = require("lapis.db")
local Model
Model = require("lapis.db.model").Model
local slugify
slugify = require("lapis.util").slugify
local next_counter
do
  local counters = setmetatable({ }, {
    __index = function(self)
      return 1
    end
  })
  next_counter = function(name)
    do
      local _with_0 = counters[name]
      counters[name] = counters[name] + 1
      return _with_0
    end
  end
end
local next_email
next_email = function()
  return "me-" .. tostring(next_counter("email")) .. "@example.com"
end
local Users, CommunityUsers, Categories, Topics, Posts, Votes, Moderators, PostReports, CategoryMembers, Blocks, Bans, CategoryGroups, Bookmarks, PendingPosts, CategoryTags
Users = function(...)
  return require("spec.factory").Users(...)
end
CommunityUsers = function(opts)
  if opts == nil then
    opts = { }
  end
  opts.user_id = opts.user_id or Users().id
  return assert(models.CommunityUsers:create(opts))
end
Categories = function(opts)
  if opts == nil then
    opts = { }
  end
  opts.title = opts.title or "Category " .. tostring(next_counter("category"))
  return assert(models.Categories:create(opts))
end
Topics = function(opts)
  if opts == nil then
    opts = { }
  end
  local category
  if opts.category == false then
    opts.category = nil
  elseif opts.category then
    category = opts.category
    opts.category_id = category.id
    opts.category = nil
  else
    opts.category_id = opts.category_id or Categories().id
  end
  opts.user_id = opts.user_id or Users().id
  opts.title = opts.title or "Topic " .. tostring(next_counter("topic"))
  do
    local topic = assert(models.Topics:create(opts))
    topic.category = category
    if category then
      category:increment_from_topic(topic)
    end
    return topic
  end
end
Posts = function(opts)
  if opts == nil then
    opts = { }
  end
  local topic
  opts.user_id = opts.user_id or Users().id
  if opts.topic then
    topic = opts.topic
    opts.topic_id = topic.id
    opts.topic = nil
  else
    opts.topic_id = opts.topic_id or Topics({
      user_id = opts.user_id
    }).id
  end
  opts.body = opts.body or "Post " .. tostring(next_counter("post")) .. " body"
  do
    local post = assert(models.Posts:create(opts))
    post.topic = topic
    if topic then
      topic:increment_from_post(post)
    end
    return post
  end
end
Votes = function(opts)
  if opts == nil then
    opts = { }
  end
  if opts.positive == nil then
    opts.positive = true
  end
  opts.user_id = opts.user_id or Users().id
  opts.object = opts.object or Posts({
    [opts.positive and "up_votes_count" or "down_votes_count"] = 1
  })
  return assert(models.Votes:create(opts))
end
Moderators = function(opts)
  if opts == nil then
    opts = { }
  end
  opts.user_id = opts.user_id or Users().id
  if not (opts.object) then
    opts.object = Categories()
  end
  if opts.accepted == nil then
    opts.accepted = true
  end
  return assert(models.Moderators:create(opts))
end
PostReports = function(opts)
  if opts == nil then
    opts = { }
  end
  if opts.category_id then
    assert(not opts.post_id, "no post id please")
    local topic = Topics({
      category_id = opts.category_id
    })
    local post = Posts({
      topic_id = topic.id
    })
    opts.post_id = post.id
  else
    local post
    if opts.post_id then
      post = models.Posts:find(opts.post_id)
    else
      do
        post = Posts()
        opts.post_id = post.id
        post = post
      end
    end
    opts.category_id = opts.category_id or post:get_topic():get_category().id
  end
  opts.reason = opts.reason or "offensive"
  opts.body = opts.body or "hello world"
  opts.user_id = opts.user_id or Users().id
  return assert(models.PostReports:create(opts))
end
CategoryMembers = function(opts)
  if opts == nil then
    opts = { }
  end
  opts.user_id = opts.user_id or Users().id
  opts.category_id = opts.category_id or Categories().id
  if opts.accepted == nil then
    opts.accepted = true
  end
  return assert(models.CategoryMembers:create(opts))
end
Blocks = function(opts)
  if opts == nil then
    opts = { }
  end
  opts.blocking_user_id = opts.blocking_user_id or Users().id
  opts.blocked_user_id = opts.blocked_user_id or Users().id
  return assert(models.Blocks:create(opts))
end
Bans = function(opts)
  if opts == nil then
    opts = { }
  end
  opts.object = opts.object or Categories()
  opts.banned_user_id = opts.banned_user_id or Users().id
  opts.reason = opts.reason or "this user is banned"
  opts.banning_user_id = opts.banning_user_id or Users().id
  return assert(models.Bans:create(opts))
end
CategoryGroups = function(opts)
  if opts == nil then
    opts = { }
  end
  opts.title = opts.title or "Category group " .. tostring(next_counter("category-group"))
  return assert(models.CategoryGroups:create(opts))
end
Bookmarks = function(opts)
  if opts == nil then
    opts = { }
  end
  opts.object_type = opts.object_type or "topic"
  opts.object_id = opts.object_id or Topics().id
  opts.user_id = opts.user_id or Users().id
  return assert(models.Bookmarks:create(opts))
end
PendingPosts = function(opts)
  if opts == nil then
    opts = { }
  end
  if not (opts.topic_id) then
    local topic = Topics({
      category_id = opts.category_id
    })
    opts.topic_id = topic.id
    opts.category_id = topic.category_id
  end
  opts.user_id = opts.user_id or Users().id
  opts.body = opts.body or "Pending post " .. tostring(next_counter("post")) .. " body"
  return assert(models.PendingPosts:create(opts))
end
CategoryTags = function(opts)
  if opts == nil then
    opts = { }
  end
  opts.category_id = opts.category_id or Categories().id
  opts.label = opts.label or "Some tag " .. tostring(next_counter("tag"))
  return assert(models.CategoryTags:create(opts))
end
return {
  next_counter = next_counter,
  next_email = next_email,
  Categories = Categories,
  Topics = Topics,
  Posts = Posts,
  Votes = Votes,
  Moderators = Moderators,
  PostReports = PostReports,
  CategoryMembers = CategoryMembers,
  Blocks = Blocks,
  Bans = Bans,
  CategoryGroups = CategoryGroups,
  Bookmarks = Bookmarks,
  CommunityUsers = CommunityUsers,
  PendingPosts = PendingPosts,
  CategoryTags = CategoryTags
}
