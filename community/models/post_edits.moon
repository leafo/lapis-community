
import Model, constraints from require "lapis.db.model"

class PostEdits extends Model
  @timestamp: true

  @relations: {
    post: "Posts"
    user: "Users"
  }

  @create: (opts={}) =>
    assert opts.post_id, "missing post_id"
    assert opts.user_id, "missing user_id"
    assert opts.body_before, "missing body_before"
    Model.create @, opts

