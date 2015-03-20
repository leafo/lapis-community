
import Flow from require "lapis.flow"

import Topics from require "models"

import assert_error from require "lapis.application"
import trim_filter from require "lapis.util"
import assert_valid from require "lapis.validate"

class TopicsFlow extends Flow
  expose_assigns: true

  new: (req) =>
    super req
    assert @current_user, "missing current user for post flow"

  _assert_topic: =>
    assert_valid @params, {
      {"topic_id", is_integer: true}
    }

    @topic = Topics\find @params.topic_id
    assert_error @topic, "invalid category"

  set_tags: =>
    @_assert_topic!
    assert_error @topic\allowed_to_moderate(@current_user), "invalid user"
    import TopicTags from require "models"

    @topic\set_tags @params.tags or ""
    true

