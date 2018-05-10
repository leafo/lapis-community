
import Users from require "models"

import mock_request from require "lapis.spec.request"

import Application from require "lapis"

assert = require "luassert"

merge = (t, t1, ...) ->
  if t1
    out = {k,v for k,v in pairs t}
    for k,v in pairs t1
      out[k] = v

    merge out, ...
  else
    t


-- to prevent sparse array error
filter_bans = (thing, ...) ->
  return unless thing
  thing.user_bans = nil
  if thing.category or thing.topic
    rest = {...}

    table.insert rest, thing.category if thing.category
    table.insert rest, thing.topic if thing.topic

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


{ :TestApp, :filter_bans, :merge }
