import enum from require "lapis.db.model"
import Model from require "community.model"

import safe_insert from require "community.helpers.models"

class ModerationLogObjects extends Model
  @timestamp: true

  @relations: {
    {"moderation_log", belongs_to: "ModerationLogs"}

    {"object", polymorphic_belongs_to: {
      [1]: {"user", "Users"}
      [2]: {"topic", "Topics"}
    }}
  }

  @create: safe_insert
