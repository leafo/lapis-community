
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
    import Posts, CommunityUsers from require "community.models"

    post = Posts\create {
      topic_id: @topic_id
      user_id: @user_id
      parent_post: @parent_post
      body: @body
      created_at: @created_at
    }

    topic = @get_topic!

    topic\increment_from_post post

    if category = topic\get_category!
      category\increment_from_post post

    CommunityUsers\for_user(@get_user!)\increment "posts_count"
    topic\increment_participant @get_user!

    post


