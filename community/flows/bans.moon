
import Flow from require "lapis.flow"

import assert_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import trim_filter from require "lapis.util"

import Users from require "models"
import Bans, Categories, Topics from require "community.models"

class BansFlow extends Flow
  expose_assigns: true

  new: (req) =>
    super req
    assert @current_user, "missing current user for bans flow"

  -- or user to ban
  load_banned_user: =>
    assert_valid @params, {
      {"banned_user_id", is_integer: true}
    }

    @banned = assert_error Users\find(@params.banned_user_id), "invalid user"
    assert_error @banned.id != @current_user.id, "invalid user"

  load_object: =>
    return if @object

    assert_valid @params, {
      {"object_id", is_integer: true }
      {"object_type", one_of: Bans.object_types}
    }

    model = Bans\model_for_object_type @params.object_type
    @object = model\find @params.object_id

    assert_error @object, "invalid ban object"
    assert_error @object\allowed_to_moderate(@current_user), "invalid permissions"


  write_moderation_log: (action, reason, log_objects) =>
    @load_object!

    import ModerationLogs from require "community.models"

    category_id = switch @params.object_type
      when "category"
        @object.id
      when "topic"
        @object.category_id

    ModerationLogs\create {
      user_id: @current_user.id
      object: @object
      :category_id
      :action
      :reason
      :log_objects
    }

  ban: =>
    @load_banned_user!
    @load_object!

    trim_filter @params
    assert_valid @params, {
      {"reason", exists: true}
    }

    ban = Bans\create {
      object: @object
      reason: @params.reason
      banned_user_id: @banned.id
      banning_user_id: @current_user.id
    }

    if ban
      @write_moderation_log "#{@params.object_type}.ban",
        @params.reason,
        { @banned }

    true

  unban: =>
    @load_banned_user!
    @load_object!

    ban = Bans\find {
      object_type: Bans.object_types\for_db @params.object_type
      object_id: @object.id
      banned_user_id: @banned.id
    }

    if ban and ban\delete!
      @write_moderation_log "#{@params.object_type}.unban", nil, { @banned }

    true
