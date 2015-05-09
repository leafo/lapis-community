db = require "lapis.db"
import Model from require "community.model"

class PostVotes extends Model
  @timestamp: true
  @primary_key: {"user_id", "post_id"}

  @relations: {
    {"post", belongs_to: "Posts"}
    {"user", belongs_to: "Users"}
  }

  @create: (opts={}) =>
    assert opts.user_id, "missing user id"
    assert opts.post_id, "missing post id"
    Model.create @, opts

  @vote: (post, user, positive=true) =>
    import upsert from require "community.helpers.models"

    existing = @find user.id, post.id

    params = {
      post_id: post.id
      user_id: user.id
      positive: not not positive
    }

    action = upsert @, params

    -- decrement and increment if positive changed
    existing\decrement! if existing
    @load(params)\increment!

    action

  unvote: (post, user) =>
    clause = {
      post_id: post.id
      user_id: user.id
    }

    res = unpack db.query "
      delete from #{db.escape_identifier @table_name!}
      where #{db.encode_clause clause}
      returning *
    "

    return unless res

    deleted_vote = @load res
    deleted_vote\decrement!
    true

  name: =>
    @positive and "positive" or "negative"

  increment: =>
    import Posts from require "community.models"
    counter_name = @post_counter_name!
    db.update Posts\table_name!, {
      [counter_name]: db.raw "#{db.escape_identifier counter_name} + 1"
    }, {
      id: @post_id
    }

  decrement: =>
    import Posts from require "community.models"
    counter_name = @post_counter_name!
    db.update Posts\table_name!, {
      [counter_name]: db.raw "#{db.escape_identifier counter_name} - 1"
    }, {
      id: @post_id
    }

  post_counter_name: =>
    if @positive
      "up_votes_count"
    else
      "down_votes_count"
