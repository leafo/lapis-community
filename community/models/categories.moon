db = require "lapis.db"
import Model, enum from require "lapis.db.model"

import slugify from require "lapis.util"

class Categories extends Model
  @timestamp: true

  @membership_types: enum {
    public: 1
    members_only: 2
  }

  @relations: {
    {"moderators", has_many: "CategoryModerators", key: "category_id", where: {accepted: true}}
  }

  @create: (opts={}) =>
    assert opts.name, "missing name"
    opts.membership_type = @membership_types\for_db opts.membership_type or "public"
    opts.slug or= slugify opts.name

    Model.create @, opts

  allowed_to_post: (user) =>
    return nil, "no user" unless user
    true

  allowed_to_view: (user) =>
    swtich @membership_types[@membership_type]
    when "public"
      true
    when "members_only"
      return false unless user
      return true if @allowed_to_moderate user
      import CategoryMembers from require "models"
      membership = CategoryMembers\find {
        user_id: user.id
        category_id: @id
        approved: true
      }

      not not membership

  allowed_to_edit_moderators: (user) =>
    return nil unless user
    return true if user\is_admin!
    return true if user.id == @user_id
    if mod = @find_moderator user
      return true if mod.accepted and mod.admin

    false

  allowed_to_edit_members: (user) =>
    return nil unless user
    return @allowed_to_moderate user

  allowed_to_moderate: (user) =>
    return nil unless user
    return true if user\is_admin!
    return true if user.id == @user_id
    if mod = @find_moderator user
      return true if mod.accepted

    false

  find_moderator: (user) =>
    return nil unless user

    import CategoryModerators from require "models"
    CategoryModerators\find {
      category_id: @id
      user_id: user.id
    }

