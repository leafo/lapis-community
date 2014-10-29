import Model from require "lapis.db.model"

import slugify from require "lapis.util"

class Categories extends Model
  @timestamp: true

  @create: (opts={}) =>
    assert opts.name, "missing name"
    opts.slug or= slugify opts.name
    Model.create @, opts

  allowed_to_post: (user) =>
    return nil, "no user" unless user
    true
