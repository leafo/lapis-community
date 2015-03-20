
import Model from require "community.model"
import safe_insert from require "community.helpers.models"

class Blocks extends Model
  @primary_key: {"blocker_id", "blocked_id"}
  @timestamp: true

  @releations: {
    {"blocker", belongs_to: "Users"}
    {"blocked", belongs_to: "Users"}
  }

  @create: safe_insert
