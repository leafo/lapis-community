import Flow from require "lapis.flow"
db = require "lapis.db"

import assert_page from require "community.helpers.app"
import assert_valid from require "lapis.validate"
import assert_error from require "lapis.application"
types = require "lapis.validate.types"

import Subscriptions from require "community.models"

import preload from require "lapis.db.model"

class SubscriptionsFlow extends Flow
  expose_assigns: true

  new: (req) =>
    super req
    assert @current_user, "missing current user for subscription flow"

  subscribe_to_topic: (topic) =>
    assert_error topic\allowed_to_view(@current_user, @_req), "invalid topic"
    topic\subscribe @current_user

  subscribe_to_category: (category) =>
    assert_error category\allowed_to_view(@current_user, @_req), "invalid category"
    category\subscribe @current_user

  find_subscription: =>
    return @subscription if @subscription

    params = assert_valid @params, types.params_shape {
      {"object_id", types.db_id}
      {"object_type", types.db_enum Subscriptions.object_types}
    }

    @subscription = Subscriptions\find {
      object_type: Subscriptions.object_types\for_db params.object_type
      object_id: params.object_id
      user_id: @current_user.id
    }

    @subscription

  show_subscriptions: =>
    assert_page @

    -- TODO: there's no index on order
    @pager = Subscriptions\paginated "where ? order by created_at desc", db.clause({
      user_id: @current_user.id
      subscribed: true
    }), {
      per_page: 50
      prepare_results: (subs) ->
        for sub in *subs
          sub.user = @current_user

        preload subs, "object"
        subs
    }

    @subscriptions = @pager\get_page @page
  
