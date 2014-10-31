db = require "lapis.db"
import Model from require "lapis.db.model"

import slugify from require "lapis.util"

class Categories extends Model
  @timestamp: true

  @create: (opts={}) =>
    assert opts.name, "missing name"
    opts.slug or= slugify opts.name
    opts.last_post_at or= db.format_date!

    Model.create @, opts

  allowed_to_post: (user) =>
    return nil, "no user" unless user
    true

  allowed_to_view: (user) =>
    true

