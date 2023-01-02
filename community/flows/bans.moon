
db = require "lapis.db"
import Flow from require "lapis.flow"

import assert_error from require "lapis.application"
import require_current_user from require "community.helpers.app"
import preload from require "lapis.db.model"
import Bans, Categories, Topics from require "community.models"

import Users from require "models"

limits = require "community.limits"
shapes = require "community.helpers.shapes"

import types from require "tableshape"

class BansFlow extends Flow
  expose_assigns: true

  new: (req, @object) =>
    super req
    assert @current_user, "missing current user for bans flow"

  -- or user to ban
  load_banned_user: =>
    params = shapes.assert_valid @params, {
      {"banned_user_id", shapes.db_id}
    }

    @banned = assert_error Users\find(params.banned_user_id), "invalid user"
    assert_error @banned.id != @current_user.id, "you can not ban yourself"
    assert_error not @banned\is_admin!, "you can't ban an admin"

    @load_object!
    assert_error not @object\allowed_to_moderate(@banned), "you can't ban a moderator"

  load_object: =>
    return if @object
    params = shapes.assert_valid @params, {
      {"object_id", shapes.db_id}
      {"object_type", shapes.db_enum Bans.object_types}
    }

    model = Bans\model_for_object_type params.object_type
    @object = model\find params.object_id

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

    if @object.find_ban
      @ban = @object\find_ban @banned
    else
      @ban = Bans\find {
        object_type: Bans\object_type_for_object @object
        object_id: @object.id
        banned_user_id: @banned.id
      }

    @ban or= false

  write_moderation_log: (action, reason, log_objects) =>
    @load_object!

    import ModerationLogs from require "community.models"

    category_id = if @target_category
      @target_category.id
    else
      switch Bans\object_type_for_object @object
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
      object: @target_category or @object
      :category_id
      :action
      :reason
      :log_objects
    }

  create_ban: require_current_user =>
    @load_banned_user!
    @load_object!

    params = shapes.assert_valid @params, {
      {"reason", shapes.empty + shapes.limited_text limits.MAX_BODY_LEN }
      {"target_category_id", shapes.empty + shapes.db_id}
    }

    object_type_name = Bans.object_types\to_name Bans\object_type_for_object @object

    local category

    if target_id = params.target_category_id
      cs = assert_error @get_moderatable_categories!, "invalid target category"
      for c in *cs
        if tostring(target_id) == tostring(c.id)
          category = c
          break

    if object_type_name == "category"
      if category and @object.id == category.id
        category = nil

    @target_category = category

    ban = Bans\create {
      object: category or @object
      reason: params.reason
      banned_user_id: @banned.id
      banning_user_id: @current_user.id
    }

    if ban
      @write_moderation_log "#{object_type_name}.ban",
        params.reason,
        { @banned }

    ban

  delete_ban: require_current_user =>
    @load_ban!
    assert_error @ban, "invalid ban"

    object_type_name = Bans.object_types\to_name @ban.object_type

    if @ban and @ban\delete!
      @write_moderation_log "#{object_type_name}.unban", nil, { @banned }

    true

  show_bans: require_current_user =>
    @load_object!

    params = shapes.assert_valid @params, {
      {"page", shapes.page_number}
    }

    @pager = Bans\paginated [[
      where object_type = ? and object_id = ?
      order by created_at desc
    ]], Bans\object_type_for_object(@object), @object.id, {
      per_page: 20
      prepare_results: (bans) ->
        preload bans, "banned_user", "banning_user"
        bans
    }

    @bans = @pager\get_page params.page
    @bans

