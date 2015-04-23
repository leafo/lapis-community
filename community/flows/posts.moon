import Flow from require "lapis.flow"
import Topics, Posts, PostEdits, CommunityUsers from require "models"

db = require "lapis.db"
import assert_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import trim_filter, slugify from require "lapis.util"

import require_login from require "community.helpers.app"

limits = require "community.limits"

class PostsFlow extends Flow
  expose_assigns: true

  load_post: =>
    return if @post

    assert_valid @params, {
      {"post_id", is_integer: true }
    }

    @post = Posts\find @params.post_id
    assert_error @post, "invalid category"

  new_post: require_login =>
    TopicsFlow = require "community.flows.topics"
    TopicsFlow(@)\load_topic!
    assert_error @topic\allowed_to_post @current_user

    trim_filter @params
    assert_valid @params, {
      {"parent_post_id", optional: true, is_integer: true }
      {"post", type: "table"}
    }

    new_post = trim_filter @params.post
    assert_valid new_post, {
      {"body", exists: true, max_length: limits.MAX_BODY_LEN}
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

  edit_post: require_login =>
    @load_post!
    assert_error @post\allowed_to_edit(@current_user), "not allowed to edit"

    assert_valid @params, {
      {"post", type: "table"}
    }

    @topic = @post\get_topic!

    post_update = trim_filter @params.post
    assert_valid post_update, {
      {"body", exists: true, max_length: limits.MAX_BODY_LEN}
      {"reason", optional: true, max_length: limits.MAX_BODY_LEN}
    }

    -- only if the body is different
    if @post.body != post_update.body
      PostEdits\create {
        user_id: @current_user.id
        body_before: @post.body
        reason: post_update.reason
        post_id: @post.id
      }

      @post\update {
        body: post_update.body
        edits_count: db.raw "edits_count + 1"
        last_edited_at: db.format_date!
      }

    if @post\is_topic_post!
      assert_valid post_update, {
        {"title", optional: true, max_length: limits.MAX_TITLE_LEN}
      }

      if post_update.title
        @topic\update {
          title: post_update.title
          slug: slugify post_update.title
        }

    true

  delete_post: require_login =>
    @load_post!
    assert_error @post\allowed_to_edit(@current_user), "not allowed to edit"

    if @post\is_topic_post!
      @topic = @post\get_topic!
      TopicsFlow = require "community.flows.topics"
      TopicsFlow(@)\delete_topic!
      return true

    if @post\delete!
      topic = @post\get_topic!
      topic\decrement_participant @current_user
      true

  vote_post: require_login =>
    import PostVotes from require "models"

    @load_post!
    assert_error @post\allowed_to_vote @current_user

    if @params.action
      assert_valid @params, {
        {"action", one_of: {"remove"}}
      }

      switch @params.action
        when "remove"
          if PostVotes\unvote @post, @current_user
            CommunityUsers\for_user(@current_user)\increment "votes_count", -1

    else
      assert_valid @params, {
        {"direction", one_of: {"up", "down"}}
      }

      _, action = PostVotes\vote @post, @current_user, @params.direction == "up"

      if action == "insert"
        CommunityUsers\for_user(@current_user)\increment "votes_count"

    true
