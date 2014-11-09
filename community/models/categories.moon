db = require "lapis.db"
import Model from require "lapis.db.model"

import slugify from require "lapis.util"

class Categories extends Model
  @timestamp: true

  @create: (opts={}) =>
    assert opts.name, "missing name"
    opts.slug or= slugify opts.name

    Model.create @, opts

  allowed_to_post: (user) =>
    return nil, "no user" unless user
    true

  allowed_to_view: (user) =>
    true

  allowed_to_edit_moderators: (user) =>
    return nil unless user
    return true if user\is_admin!
    return true if user.id == @user_id
    if mod = @find_moderator user
      return true if mod.accepted and mod.admin

    false

  find_moderator: (user) =>
    return nil unless user

    import CategoryModerators from require "models"
    CategoryModerators\find {
      category_id: @id
      user_id: user.id
    }

