db = require "lapis.db"
import Model from require "lapis.db.model"

class PostVotes extends Model
  @timestamp: true
  @primary_key: {"user_id", "post_id"}

  @create: (opts={}) =>
    assert opts.user_id, "missing user id"
    assert opts.post_id, "missing post id"
    Model.create @, opts


  @vote: (post, user, positive=true) =>
    import upsert from require "community.helpers.models"
    upsert @, {
      post_id: post.id
      user_id: user.id
      positive: not not positive
    }

