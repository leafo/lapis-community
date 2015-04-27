
db = require "lapis.db"
import Model from require "community.model"

class TopicParticipants extends Model
  @primary_key: {"topic_id", "user_id"}
  @timestamp: true

  @relations: {
    {"user", belongs_to: "Users"}
    {"topic", belongs_to: "Topics"}
  }

  @increment: (topic_id, user_id) =>
    import upsert from require "community.helpers.models"

    upsert @, {
      :user_id, :topic_id
      posts_count: 1
    }, {
      posts_count: db.raw "posts_count + 1"
    }

  @decrement: (topic_id, user_id) =>
    key = {:user_id, :topic_id}

    res = db.update @table_name!, {
      posts_count: db.raw "posts_count - 1"
    }, key, "posts_count"

    if res[1] and res[1].posts_count == 0
      key.posts_count = 0
      db.delete @table_name!, key
