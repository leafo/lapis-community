
import Users from require "models"

import mock_request from require "lapis.spec.request"

import Application from require "lapis"

assert = require "luassert"

-- to prevent sparse array error
filter_bans = (thing, ...) ->
  return unless thing
  thing.user_bans = nil
  if thing.category
    rest = {...}
    table.insert rest, thing.category
    thing, filter_bans unpack rest
  else
    thing, filter_bans ...

class TestApp extends Application
  @require_user: =>
    @before_filter =>
      @current_user = Users\find assert @params.current_user_id, "missing user id"

  @get: (user, path, get={}) =>
    if user
      get.current_user_id or= user.id

    status, res = mock_request @, path, {
      :get
      expect: "json"
    }

    assert.same 200, status
    res


{ :TestApp, :filter_bans }
