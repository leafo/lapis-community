
import Model from require "community.model"
import safe_insert from require "community.helpers.models"

class Blocks extends Model
  @primary_key: {"blocking_user_id", "blocked_user_id"}
  @timestamp: true

  @releations: {
    {"blocking_user", belongs_to: "Users"}
    {"blocked_user", belongs_to: "Users"}
  }

  @create: safe_insert
