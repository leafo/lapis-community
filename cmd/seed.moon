
factory = require "spec.factory"

words = [word for word in io.open("/usr/share/dict/american-english")\lines!]

sentence = (num_words=5) ->
  table.concat [words[math.random 1, #words] for i=1,num_words], " "

leafo = factory.Users username: "leafo"
lee = factory.Users username: "lee"

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

for i=1,10
  topic = factory.Topics {
    category_id: cat1.id
    user_id: leafo.id
    title: sentence math.random 2, 5
  }

  factory.Posts {
    user_id: leafo.id
    topic_id: topic.id
    body: sentence math.random 8, 10
  }

  factory.Posts {
    user_id: lee.id
    topic_id: topic.id
    body: sentence math.random 8, 10
  }

  topic\recount!

cat1\recount!

