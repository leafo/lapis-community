
db = require "lapis.db"
import Flow from require "lapis.flow"

import assert_error from require "lapis.application"
import assert_valid from require "lapis.validate"
import trim_filter from require "lapis.util"

import assert_page, require_login from require "community.helpers.app"

import Users from require "models"
import Bans, Categories, Topics from require "community.models"

import preload from require "lapis.db.model"

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

  -- get all the categories up the ancestor tree that the moderator has access to
  get_moderatable_categories: =>
    @load_object!
    return unless @object.__class.__name == "Categories"

    categories = {
      @object
      unpack @object\get_ancestors!
    }

    if @current_user\is_admin!
      return categories

    ids = @object\get_category_ids!
    import Moderators from require "community.models"
    mods = Moderators\select "
      where object_type = ?
      and object_id in ?
      and user_id = ?
      and accepted
    ", Moderators.object_types.category, db.list(ids), @current_user.id

    mods_by_category_id = { mod.object_id, mod for mod in *mods }

    for k=#categories,1,-1
      cat = categories[k]
      mod = mods_by_category_id[cat.id]
      if mod
        return [cat for cat in *categories[1,k]]

    {}

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
        preload bans, "banned_user", "banning_user"
        bans
    }

    @bans = @pager\get_page @page
    @bans

