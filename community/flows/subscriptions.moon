import Flow from require "lapis.flow"
db = require "lapis.db"

import assert_page from require "community.helpers.app"
import assert_valid from require "lapis.validate"

import Subscriptions from require "community.models"

import preload from require "lapis.db.model"

class SubscriptionsFlow extends Flow
  expose_assigns: true

  new: (req) =>
    super req
    assert @current_user, "missing current user for bookmarks flow"

  find_subscription: =>
    return @subscription if @subscription

    assert_valid @params, {
      {"object_id", is_integer: true}
      {"object_type", one_of: Subscriptions.object_types}
    }

    @subscription = Subscriptions\find {
      object_type: Subscriptions.object_types\for_db @params.object_type
      object_id: @params.object_id
      user_id: @current_user.id
    }

    @subscription

  show_subscriptions: =>
    -- TODO: there's no index on order
    @pager = Subscriptions\paginated "
      where user_id = ? and subscribed
      order by created_at desc
    ", @current_user.id, {
      per_page: 50
      prepare_results: (subs) ->

        for sub in *subs
          sub.user = @current_user

        preload subs, "object"
        subs
    }

    assert_page @
    @subscriptions = @pager\get_page @page
  
