
import Model from require "community.model"

class PostEdits extends Model
  @timestamp: true

  @relations: {
    {"post", belongs_to: "Posts"}
    {"user", belongs_to: "Users"}
  }

  @create: (opts={}) =>
    assert opts.post_id, "missing post_id"
    assert opts.user_id, "missing user_id"
    assert opts.body_before, "missing body_before"
    Model.create @, opts

