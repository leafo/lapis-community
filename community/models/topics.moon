db = require "lapis.db"

import Model from require "community.model"
import slugify from require "lapis.util"

class Topics extends Model
  @timestamp: true

  @relations: {
    {"category", belongs_to: "Categories"}
    {"user", belongs_to: "Users"}
  }

  @create: (opts={}) =>
    assert opts.category_id, "missing category_id"
    assert opts.user_id, "missing user_id"
    assert opts.title, "missing user_id"
    opts.slug or= slugify opts.title
    opts.last_post_at or= db.format_date!

    Model.create @, opts

  allowed_to_post: (user) =>
    return false if @deleted
    return false if @locked
    return nil, "no user" unless user
    true

  allowed_to_view: (user) =>
    return false if @deleted
    true

  allowed_to_edit: (user) =>
    return false if @deleted
    return false unless user
    return true if user.id == @user_id
    return true if user\is_admin!
    return true if @allowed_to_moderate user

    false

  allowed_to_moderate: (user) =>
    return false unless user
    import Categories from require "models"
    Categories\load(id: @category_id)\allowed_to_moderate user

  delete: =>
    import soft_delete from require "community.helpers.models"

    if soft_delete @
      import CommunityUsers from require "models"
      CommunityUsers\for_user(@get_user!)\increment "topics_count", -1
      return true

    false
