
import Flow from require "lapis.flow"

db = require "lapis.db"

import assert_error from require "lapis.application"
import assert_valid from require "lapis.validate"

import Users from require "models"
import Bookmarks from require "community.models"

import require_current_user, assert_page from require "community.helpers.app"

import preload from require "lapis.db.model"

types = require "lapis.validate.types"

class BookmarksFlow extends Flow
  expose_assigns: true

  new: (req) =>
    super req
    assert @current_user, "missing current user for bookmarks flow"

  load_object: =>
    return if @object

    params = assert_valid @params, types.params_shape {
      {"object_id", types.db_id}
      {"object_type", types.db_enum Bookmarks.object_types}
    }

    model = Bookmarks\model_for_object_type params.object_type
    @object = model\find params.object_id

    assert_error @object, "invalid bookmark object"

    @bookmark = Bookmarks\get @object, @current_user
  
  show_topic_bookmarks: require_current_user =>
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
        preload topics, "category"
        Topics\preload_bans topics, @current_user

        categories = [t\get_category! for t in *topics]
        Categories\preload_bans categories, @current_user
        preload categories, "tags"
        BrowsingFlow(@)\preload_topics topics
        topics
    }

    assert_page @
    @topics = @pager\get_page @page

  save_bookmark: =>
    @load_object!
    assert_error @object\allowed_to_view(@current_user, @_req), "invalid object"
    Bookmarks\save @object, @current_user

  remove_bookmark: =>
    @load_object!
    Bookmarks\remove @object, @current_user

