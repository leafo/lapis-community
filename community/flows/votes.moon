import Flow from require "lapis.flow"
import Votes, CommunityUsers from require "community.models"

db = require "lapis.db"
import assert_error from require "lapis.application"
import assert_valid from require "lapis.validate"

import require_current_user from require "community.helpers.app"

types = require "lapis.validate.types"

class VotesFlow extends Flow
  expose_assigns: true

  load_object: =>
    return if @object

    params = assert_valid @params, types.params_shape {
      {"object_id", types.db_id}
      {"object_type", types.db_enum Votes.object_types}
    }

    model = Votes\model_for_object_type params.object_type
    @object = model\find params.object_id
    assert_error @object, "invalid vote object"

  vote: require_current_user =>
    @load_object!

    if @params.action
      params = assert_valid @params, types.params_shape {
        {"action", types.one_of {"remove"}}
      }

      switch params.action
        when "remove"
          assert_error @object\allowed_to_vote(@current_user, "remove"),
            "not allowed to unvote"

          Votes\unvote @object, @current_user

    else
      params = assert_valid @params, types.params_shape {
        {"direction", types.one_of {"up", "down"}}
      }

      assert_error @object\allowed_to_vote(@current_user, @params.direction),
        "not allowed to vote"

      @vote = Votes\vote @object, @current_user, @params.direction == "up"
      assert_error @vote, "vote changed in another request"

    true

