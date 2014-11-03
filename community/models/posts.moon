db = require "lapis.db"
import Model from require "lapis.db.model"

class Posts extends Model
  @timestamp: true

  @relations: {
    topic: "Topics"
    user: "Users"
  }

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

  is_topic_post: =>
    @post_number == 1

  allowed_to_vote: (user) =>
    return false unless user
    return false if @deleted
    true

  allowed_to_edit: (user) =>
    return false unless user
    return true if user\is_admin!
    return true if user.id == @user_id
    return false if @deleted

    topic = @get_topic!

    import CategoryModerators from require "models"

    moderator = CategoryModerators\find {
      category_id: topic.category_id
      user_id: user.id
    }

    return true if moderator
    false
