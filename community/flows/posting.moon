
import Flow from require "lapis.flow"

db = require "lapis.db"
import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"

import trim_filter, slugify from require "lapis.util"

import Categories, Topics, Posts, PostEdits, CommunityUsers, TopicParticipants from require "models"

MAX_BODY_LEN = 1024 * 10
MAX_TITLE_LEN = 256

class Posting extends Flow
  new: (req) =>
    super req
    assert @current_user, "missing current user for post flow"

  new_topic: =>
    assert_valid @params, {
      {"category_id", is_integer: true }
      {"topic", type: "table"}
    }

    @category = assert_error Categories\find(@params.category_id), "invalid category"
    assert_error @category\allowed_to_post @current_user

    new_topic = trim_filter @params.topic
    assert_valid new_topic, {
      {"body", exists: true, max_length: MAX_BODY_LEN}
      {"title", exists: true, max_length: MAX_TITLE_LEN}
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
    CommunityUsers\for_user(@current_user)\increment "topics_count"
    @topic\increment_participant @current_user

    true

  delete_topic: =>
    assert_valid @params, {
      {"topic_id", is_integer: true }
    }

    @topic = assert_error Topics\find(@params.topic_id), "invalid topic"
    assert_error @topic\allowed_to_edit(@current_user), "not allowed to edit"

    @topic\delete!

  new_post: =>
    trim_filter @params
    assert_valid @params, {
      {"topic_id", is_integer: true }
      {"parent_post_id", optional: true, is_integer: true }
      {"post", type: "table"}
    }

    @topic = assert_error Topics\find(@params.topic_id), "invalid post"
    assert_error @topic\allowed_to_post @current_user

    new_post = trim_filter @params.post
    assert_valid new_post, {
      {"body", exists: true, max_length: MAX_BODY_LEN}
    }

    parent_post = if pid = @params.parent_post_id
      Posts\find pid

    if parent_post
      assert_error parent_post.topic_id == @topic.id,
        "topic id mismatch (#{parent_post.topic_id} != #{@topic.id})"

    @post = Posts\create {
      user_id: @current_user.id
      topic_id: @topic.id
      body: new_post.body
      :parent_post
    }

    @topic\update { posts_count: db.raw "posts_count + 1" }, timestamp: false
    CommunityUsers\for_user(@current_user)\increment "posts_count"
    @topic\increment_participant @current_user

    true

  edit_post: =>
    assert_valid @params, {
      {"post_id", is_integer: true }
      {"post", type: "table"}
    }

    @post = Posts\find @params.post_id
    assert_error @post, "invalid post"
    assert_error @post\allowed_to_edit(@current_user), "not allowed to edit"

    @topic = @post\get_topic!

    post_update = trim_filter @params.post
    assert_valid post_update, {
      {"body", exists: true, max_length: MAX_BODY_LEN}
      {"reason", optional: true, max_length: MAX_BODY_LEN}
    }

    PostEdits\create {
      user_id: @current_user.id
      body_before: @post.body
      reason: post_update.reason
      post_id: @post.id
    }

    @post\update body: post_update.body

    if @post\is_topic_post!
      assert_valid post_update, {
        {"title", optional: true, max_length: MAX_TITLE_LEN}
      }

      if post_update.title
        @topic\update {
          title: post_update.title
          slug: slugify post_update.title
        }

    true

  delete_post: =>
    assert_valid @params, {
      {"post_id", is_integer: true }
    }

    @post = assert_error Posts\find(@params.post_id), "invalid post"
    assert_error @post\allowed_to_edit(@current_user), "not allowed to edit"

    if @post\delete!
      topic = @post\get_topic!
      topic\decrement_participant @current_user
      true

  vote_post: =>
    assert_valid @params, {
      {"post_id", is_integer: true }
      {"direction", one_of: {"up", "down"}}
    }

    @post = assert_error Posts\find(@params.post_id), "invalid post"
    assert_error @post\allowed_to_vote @current_user
    import PostVotes from require "models"
    _, action = PostVotes\vote @post, @current_user, @params.direction == "up"

    if action == "insert"
      CommunityUsers\for_user(@current_user)\increment "votes_count"

    true


