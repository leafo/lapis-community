
import Model, enum from require "lapis.db.model"

class PostReports extends Model
  @timestamp: true

  @statuses: enum {
    pending: 1
    resolved: 2
    ignored: 3
  }

  @reasons: enum {
    other: 1
    offensive: 2
  }

  @create: (opts={}) =>
    opts.status or= "pending"
    opts.status = @statuses\for_db opts.status

    opts.reason = @reasons\for_db opts.reason

    assert opts.body, "missing body"
    assert opts.post_id, "missing post_id"
    assert opts.category_id, "missing category_id"
    assert opts.user_id, "missing user_id"

    Model.create @, opts

