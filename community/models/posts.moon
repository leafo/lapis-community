import Model from require "lapis.db.model"

class Posts extends Model
  @timestamp: true

  @create: (opts={}) =>
    assert opts.topic_id, "missing topic id"
    assert opts.user_id, "missing user id"
    assert opts.body, "missing body"

    Model.create @, opts


