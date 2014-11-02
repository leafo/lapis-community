
import Model from require "lapis.db.model"

class PostReplies extends Model
  @primary_key: {"user_id", "post_id"}

