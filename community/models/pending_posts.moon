
db = require "lapis.db"
import Model from require "community.model"

import enum from require "lapis.db.model"

class PendingPosts extends Model
  @timestamp: true

  @relations: {
    {"topic", belongs_to: "Topics"}
    {"user", belongs_to: "Users"}
    {"parent_post", belongs_to: "Posts"}
  }

  @statuses: enum {
    pending: 1
    deleted: 2
  }

  @create: (opts={}) =>
    opts.status = @statuses\for_db opts.status or "pending"
    Model.create @, opts

  -- convert to real post
  promote: =>

