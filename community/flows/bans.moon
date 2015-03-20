
import Flow from require "lapis.flow"

import assert_error from require "lapis.application"
import assert_valid from require "lapis.validate"

import Bans, Users, Categories, Topics from require "models"

class BansFlow extends Flow
  expose_assigns: true

  new: (req) =>
    super req
    assert @current_user, "missing current user for post flow"

  _do_ban: (object) =>
    Bans\create {
      :object
      reason: @params.reason
      banned_user_id: @banned.id
      banning_user_id: @current_user.id
    }

  _assert_category: =>
    assert_valid @params, {
      {"category_id", is_integer: true}
    }

    @category = Categories\find @params.category_id
    assert_error @category\allowed_to_moderate(@current_user), "invalid permissions"

  _assert_topic: =>
    assert_valid @params, {
      {"topic_id", is_integer: true}
    }

    @topic = Topics\find @params.topic_id
    assert_error @topic\allowed_to_moderate(@current_user), "invalid permissions"

  _assert_banned_user: =>
    assert_valid @params, {
      {"banned_user_id", is_integer: true}
    }

    @banned = assert_error Users\find(@params.banned_user_id), "invalid user"
    assert_error @banned.id != @current_user.id, "invalid user"

  ban_from_category: =>
    @_assert_banned_user!
    @_assert_category!

    assert_valid @params, {
      {"reason", exists: true}
    }

    @_do_ban @category

  unban_from_category: =>
    @_assert_banned_user!
    @_assert_category!

    ban = Bans\find {
      object_type: Bans.object_types\for_db "category"
      object_id: @category.id
      banned_user_id: @banned.id
    }

    ban\delete! if ban
    true

  ban_from_topic: =>
    @_assert_banned_user!
    @_assert_topic!

    assert_valid @params, {
      {"reason", exists: true}
    }

    @_do_ban @topic

  unban_from_topic: =>
    @_assert_banned_user!
    @_assert_topic!

    ban = Bans\find {
      object_type: Bans.object_types\for_db "topic"
      object_id: @topic.id
      banned_user_id: @banned.id
    }

    ban\delete! if ban
    true
