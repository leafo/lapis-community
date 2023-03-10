db = require "lapis.db"
factory = require "spec.factory"

import types from require "tableshape"

date = require "date"

describe "models.warnings", ->
  import Users from require "spec.models"
  import Warnings, CommunityUsers from require "spec.community_models"

  it "creates a warning", ->
    user = factory.Users!
    w = Warnings\create {
      user_id: user.id
      duration: "1 day"
      reason: "You did something bad"
    }

    cu = CommunityUsers\for_user user

    assert_warning = types.assert types.shape {
      types.partial {
        id: w.id
        user_id: cu.user_id
      }
    }

    assert_warning cu\get_active_warnings!

  it "makes a warning active", ->
    user = factory.Users!
    w = Warnings\create {
      user_id: user.id
      duration: "1 day"
      reason: "You did something bad"
    }

    -- it's active because it hasn't been started yet
    assert.same true, w\is_active!, "Unstarted warning should be active"

    assert.same true, (w\start_warning!), "Unstarted warning should start"

    assert.same true, w\is_active!, "Started warning should be active"

    expected_warning = types.partial {
      expires_at: types.string
      first_seen_at: types.string
    }

    assert expected_warning w

    expires_at = w.expires_at

    duration = date.diff(date(w.expires_at), date(w.first_seen_at))\spandays!

    -- we multiply by 10 and floor to compare floats safely
    assert.same 10, math.floor(duration*10), "Duration should be 1 day"

    -- starting an already started warning has no effect
    assert.same false, (w\start_warning!)

    assert.true w\end_warning!, "active warning should be expired immediately"
    assert.not.same w.expires_at, expires_at, "expires_at should be changed when immediately expiring"
    assert.false w\is_active!, "ended warning is no longer active"

  it "expired warning", ->
    user = factory.Users!
    w = Warnings\create {
      user_id: user.id
      duration: "1 day"
      reason: "You did something bad"
      first_seen_at: db.raw "date_trunc('second', now() at time zone 'utc') - '10 days'::interval"
      expires_at: db.raw "date_trunc('second', now() at time zone 'utc') - '9 days'::interval"
    }

    assert.false w\is_active!, "expired warning should not be active"
    assert.false w\end_warning!, "you can't end an expired warning"

    -- it should not return expired warning
    cu = CommunityUsers\for_user user
    assert.same {}, cu\get_active_warnings!

