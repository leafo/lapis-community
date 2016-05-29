import Flow from require "lapis.flow"
db = require "lapis.db"

import assert_page from require "community.helpers.app"

class SubscriptionsFlow extends Flow
  expose_assigns: true

  new: (req) =>
    super req
    assert @current_user, "missing current user for bookmarks flow"

  show_subscriptions: =>
    import Subscriptions from require "community.models"
    -- TODO: there's no index on order
    @pager = Subscriptions\paginated "
      where user_id = ? and subscribed
      order by created_at desc
    ", @current_user.id, {
      per_page: 50
      prepare_results: (subs) ->

        for sub in *subs
          sub.user = @current_user

        Subscriptions\preload_relations subs, "object"
        subs
    }

    assert_page @
    @subscriptions = @pager\get_page @page
  
