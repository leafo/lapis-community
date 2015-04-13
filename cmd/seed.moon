
factory = require "spec.factory"


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
  }

  factory.Posts {
    user_id: leafo.id
    topic_id: topic.id
  }

  factory.Posts {
    user_id: lee.id
    topic_id: topic.id
  }


