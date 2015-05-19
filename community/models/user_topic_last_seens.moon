db = require "lapis.db"
import Model from require "community.model"

class UserTopicLastSeens extends Model
  @primary_key: {"user_id", "topic_id"}

  @relations: {
    {"user", belongs_to: "Users"}
    {"topic", belongs_to: "Topics"}
    {"post", belongs_to: "Posts"}
  }

