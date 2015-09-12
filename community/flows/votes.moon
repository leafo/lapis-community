import Flow from require "lapis.flow"
import Votes, CommunityUsers from require "community.models"

db = require "lapis.db"
import assert_error from require "lapis.application"
import assert_valid from require "lapis.validate"

import require_login from require "community.helpers.app"

class VotesFlow extends Flow
  expose_assigns: true

  load_object: =>
    return if @object

    assert_valid @params, {
      {"object_id", is_integer: true }
      {"object_type", one_of: Votes.object_types}
    }

    model = Votes\model_for_object_type @params.object_type
    @object = model\find @params.object_id
    assert_error @object, "invalid vote object"

  vote: require_login =>
    @load_object!

    if @params.action
      assert_valid @params, {
        {"action", one_of: {"remove"}}
      }

      switch @params.action
        when "remove"
          assert_error @object\allowed_to_vote(@current_user, "remove"),
            "not allowed to unvote"

          if Votes\unvote @object, @current_user
            CommunityUsers\for_user(@current_user)\increment "votes_count", -1

    else
      assert_valid @params, {
        {"direction", one_of: {"up", "down"}}
      }

      assert_error @object\allowed_to_vote(@current_user, @params.direction),
        "not allowed to vote"

      action, @vote = Votes\vote @object, @current_user, @params.direction == "up"
      if action == "insert"
        CommunityUsers\for_user(@current_user)\increment "votes_count"

    true

