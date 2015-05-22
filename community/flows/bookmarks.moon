
import Flow from require "lapis.flow"

import assert_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import trim_filter from require "lapis.util"

import Users from require "models"
import Bookmarks from require "community.models"

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

    assert_error @object, "invalid ban object"

    @bookmark = Bookmarks\find {
      object_type: Bookmarks\object_type_for_object @object
      object_id: @object.id
      user_id: @current_user.id
    }

  save_bookmark: =>
    @load_object!
    assert_error @object\allowed_to_view(@current_user), "invalid object"

    Bookmarks\create {
      object_type: Bookmarks\object_type_for_object @object
      object_id: @object.id
      user_id: @current_user.id
    }

  remove_bookmark: =>
    @load_object!
    @bookmark\delete!

