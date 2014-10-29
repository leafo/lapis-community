import Model from require "lapis.db.model"
import slugify from require "lapis.util"

class Topics extends Model
  @timestamp: true

  @create: (opts={}) =>
    assert opts.category_id, "missing category_id"
    assert opts.user_id, "missing user_id"
    assert opts.title, "missing user_id"
    opts.slug or= slugify opts.title

    Model.create @, opts

