
import enum from require "lapis.db.model"
import Model from require "community.model"

class PostReports extends Model
  @timestamp: true

  @statuses: enum {
    pending: 1
    resolved: 2
    ignored: 3
  }

  @reasons: enum {
    other: 1
    off_topic: 2
    spam: 3
    offensive: 4
  }

  @relations: {
    {"category", belongs_to: "Categories"}
    {"post", belongs_to: "Posts"}
  }

  @create: (opts={}) =>
    opts.status or= "pending"
    opts.status = @statuses\for_db opts.status

    opts.reason = @reasons\for_db opts.reason

    assert opts.post_id, "missing post_id"
    assert opts.user_id, "missing user_id"

    Model.create @, opts

