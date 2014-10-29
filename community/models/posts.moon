db = require "lapis.db"
import Model from require "lapis.db.model"

class Posts extends Model
  @timestamp: true

  @create: (opts={}) =>
    assert opts.topic_id, "missing topic id"
    assert opts.user_id, "missing user id"
    assert opts.body, "missing body"

    post_number = db.interpolate_query "
     (select count(*) from #{db.escape_identifier @table_name!}
     where topic_id = ?) + 1
    ", opts.topic_id

    opts.post_number = db.raw post_number
    Model.create @, opts

