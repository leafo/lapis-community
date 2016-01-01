
import Flow from require "lapis.flow"

db = require "lapis.db"

import assert_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import trim_filter from require "lapis.util"

import Users from require "models"
import Bookmarks from require "community.models"

import require_login, assert_page from require "community.helpers.app"

class BookmarksFlow extends Flow
  expose_assigns: true

  new: (req) =>
    super req
    assert @current_user, "missing current user for bookmarks flow"

  load_object: =>
    return if @object

    assert_valid @params, {
      {"object_id", is_integer: true }
      {"object_type", one_of: Bookmarks.object_types}
    }

    model = Bookmarks\model_for_object_type @params.object_type
    @object = model\find @params.object_id

    assert_error @object, "invalid bookmark object"

    @bookmark = Bookmarks\get @object, @current_user
  
  show_topic_bookmarks: require_login =>
    BrowsingFlow = require "community.flows.browsing"

    -- TODO: this query can be bad
    -- TODO: not all topics have last post
    import Topics, Categories from require "community.models"

    @pager = Topics\paginated "
      where id in (
        select object_id from #{db.escape_identifier Bookmarks\table_name!}
        where user_id = ? and object_type = ?
      )
      and not deleted
      order by last_post_id desc
    ", @current_user.id, Bookmarks.object_types.topic, {
      per_page: 50
      prepare_results: (topics) ->
        Topics\preload_relations topics, "category"
        Topics\preload_bans topics, @current_user
        Categories\preload_bans [t\get_category! for t in *topics], @current_user

        topics = BrowsingFlow(@)\preload_topics topics
        [t for t in *topics when t\allowed_to_view(@current_user)]
    }

    assert_page @
    @topics = @pager\get_page @page

  save_bookmark: =>
    @load_object!
    assert_error @object\allowed_to_view(@current_user), "invalid object"
    Bookmarks\save @object, @current_user

  remove_bookmark: =>
    @load_object!
    Bookmarks\remove @object, @current_user

