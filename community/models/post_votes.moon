db = require "lapis.db"
import Model from require "community.model"

class PostVotes extends Model
  @timestamp: true
  @primary_key: {"user_id", "post_id"}

  @create: (opts={}) =>
    assert opts.user_id, "missing user id"
    assert opts.post_id, "missing post id"
    Model.create @, opts

  @vote: (post, user, positive=true) =>
    import upsert from require "community.helpers.models"

    existing = @find user.id, post.id

    vote, action = upsert @, {
      post_id: post.id
      user_id: user.id
      positive: not not positive
    }

    -- decrement and increment if positive changed
    existing\decrement! if existing
    vote\increment!

    true, action

  increment: =>
    import Posts from require "models"
    counter_name = @post_counter_name!
    db.update Posts\table_name!, {
      [counter_name]: db.raw "#{db.escape_identifier counter_name} + 1"
    }, {
      id: @post_id
    }

  decrement: =>
    import Posts from require "models"
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
