
import Model from require "community.model"

class PostReplies extends Model
  @primary_key: {"user_id", "post_id"}

