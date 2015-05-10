

factory = require "spec.factory"

words = [word for word in io.open("/usr/share/dict/american-english")\lines!]

-- average = 1
random_normal = ->
  _random = math.random
  (_random! + _random! + _random! + _random! + _random! + _random! + _random! + _random! + _random! + _random! + _random! + _random!) / 6

pick_one = (...) ->
  num = select "#", ...
  (select math.random(num), ...)

sentence = (num_words=5) ->
  table.concat [words[math.random 1, #words] for i=1,num_words], " "

leafo = factory.Users username: "leafo", community_user: true
lee = factory.Users username: "lee", community_user: true
adam = factory.Users username: "adam", community_user: true
fart = factory.Users username: "fart", community_user: true

rand_user = -> pick_one leafo, lee, adam, fart

cat1 = factory.Categories {
  user_id: leafo.id
  title: "Leafo's category"
  membership_type: "public"
}

cat2 = factory.Categories {
  user_id: leafo.id
  title: "Lee's zone"
  membership_type: "members_only"
}

add_posts = (topic, parent_post) ->
  base_count = if parent_post
    5
  else
    22

  num_posts = math.floor base_count * random_normal!

  for i=1,num_posts
    poster = rand_user!
    post = factory.Posts {
      user_id: poster.id
      topic_id: topic.id
      body: sentence math.random 8, 10
      parent_post: parent_post
    }

    print
    k = math.abs(random_normal! - 1)
    if k > 0.1 * post.depth
      add_posts topic, post

for i=1,4 -- 77
  topic_poster = rand_user!
  topic = factory.Topics {
    category_id: cat1.id
    user_id: topic_poster.id
    title: sentence math.random 2, 5
  }

  add_posts topic

import Categories, Topics, CommunityUsers from require "community.models"
Topics\recount!
Categories\recount!
CommunityUsers\recount!
