db = require "lapis.db"

import Model from require "lapis.db.model"
import slugify from require "lapis.util"

class Topics extends Model
  @timestamp: true

  @create: (opts={}) =>
    assert opts.category_id, "missing category_id"
    assert opts.user_id, "missing user_id"
    assert opts.title, "missing user_id"
    opts.slug or= slugify opts.title
    opts.last_post_at or= db.format_date!

    Model.create @, opts

  allowed_to_post: (user) =>
    return false if @deleted
    return nil, "no user" unless user
    true

  allowed_to_view: (user) =>
    return false if @deleted
    true

