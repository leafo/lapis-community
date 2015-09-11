
import Flow from require "lapis.flow"

import assert_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import trim_filter from require "lapis.util"

import assert_page, require_login from require "community.helpers.app"

import Users from require "models"
import Bans, Categories, Topics from require "community.models"

class BansFlow extends Flow
  expose_assigns: true

  new: (req, @object) =>
    super req
    assert @current_user, "missing current user for bans flow"

  -- or user to ban
  load_banned_user: =>
    assert_valid @params, {
      {"banned_user_id", is_integer: true}
    }

    @banned = assert_error Users\find(@params.banned_user_id), "invalid user"
    assert_error @banned.id != @current_user.id, "you can not ban yourself"

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

  load_ban: =>
    return if @ban != nil

    @load_banned_user!
    @load_object!

    @ban = Bans\find {
      object_type: Bans\object_type_for_object @object
      object_id: @object.id
      banned_user_id: @banned.id
    }

    @ban or= false

  write_moderation_log: (action, reason, log_objects) =>
    @load_object!

    import ModerationLogs from require "community.models"

    category_id = switch Bans\object_type_for_object @object
      when Bans.object_types.category_group
        nil -- TODO: need a way to write moderation logs for category groups
      when Bans.object_types.category
        @object.id
      when Bans.object_types.topic
        @object.category_id
      else
        error "no category id for ban moderation log"

    ModerationLogs\create {
      user_id: @current_user.id
      object: @object
      :category_id
      :action
      :reason
      :log_objects
    }

  create_ban: =>
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

  delete_ban: =>
    @load_ban!
    assert_error @ban, "invalid ban"

    if @ban and @ban\delete!
      @write_moderation_log "#{@params.object_type}.unban", nil, { @banned }

    true

  show_bans: =>
    @load_object!
    assert_page @

    @pager = Bans\paginated [[
      where object_type = ? and object_id = ?
      order by created_at desc
    ]], Bans\object_type_for_object(@object), @object.id, {
      per_page: 20
      prepare_results: (bans) ->
        Users\include_in bans, "banned_user_id"
        Users\include_in bans, "banning_user_id"
        bans
    }

    @bans = @pager\get_page @page
    @bans

