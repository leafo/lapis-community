
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

leafo = factory.Users username: "leafo"
lee = factory.Users username: "lee"
adam = factory.Users username: "adam"
fart = factory.Users username: "fart"

rand_user = -> pick_one leafo, lee, adam, fart

cat1 = factory.Categories {
  user_id: leafo.id
  name: "Leafo's category"
  membership_type: "public"
}

cat2 = factory.Categories {
  user_id: leafo.id
  name: "Lee's zone"
  membership_type: "members_only"
}

for i=1,77
  topic_poster = rand_user!
  topic = factory.Topics {
    category_id: cat1.id
    user_id: topic_poster.id
    title: sentence math.random 2, 5
  }

  posts = math.floor 22 * random_normal!

  for i=1,posts
    poster = rand_user!
    factory.Posts {
      user_id: poster.id
      topic_id: topic.id
      body: sentence math.random 8, 10
    }

  topic\recount!

cat1\recount!

