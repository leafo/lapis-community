
import Flow from require "lapis.flow"

db = require "lapis.db"
import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"

import trim_filter from require "lapis.util"

class Posting extends Flow
  new: (req) =>
    super req
    assert @current_user, "missing current user for post flow"

  new_topic: =>
    import Categories, Topics, Posts from require "models"

    assert_valid @params, {
      {"category_id", is_integer: true }
      {"topic", type: "table"}
    }

    @category = assert_error Categories\find(@params.category_id), "invalid category"
    assert_error @category\allowed_to_post @current_user

    new_topic = trim_filter @params.topic
    assert_valid new_topic, {
      {"body", exists: true, max_length: 1024*10}
      {"title", exists: true, max_length: 256}
    }

    @topic = Topics\create {
      user_id: @current_user.id
      category_id: @category.id
      title: new_topic.title
      posts_count: 1
    }

    @post = Posts\create {
      user_id: @current_user.id
      topic_id: @topic.id
      body: new_topic.body
    }

    @category\update { topics_count: db.raw "topics_count + 1" }, timestamp: false

    true



