
db = require "lapis.db"
import Model from require "community.model"

import safe_insert from require "community.helpers.models"

-- Generated schema dump: (do not edit)
--
--
class TopicSubscriptions extends Model
  @primary_key: {"topic_id", "user_id"}
  @timestamp: true

  @relations: {
    {"user", belongs_to: "Users"}
    {"topic", belongs_to: "Topics"}
  }

  @create: safe_insert
