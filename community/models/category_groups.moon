
db = require "lapis.db"
import enum from require "lapis.db.model"
import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_category_groups (
--   id integer NOT NULL,
--   title character varying(255),
--   user_id integer,
--   categories_count integer DEFAULT 0 NOT NULL,
--   description text,
--   rules text,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_category_groups
--   ADD CONSTRAINT community_category_groups_pkey PRIMARY KEY (id);
--
class CategoryGroups extends Model
  @timestamp: true

  @voting_types: enum {
    up_down: 1
    up: 2
    disabled: 3
  }

  @relations: {
    -- TODO: see comment in Categories
    {"moderators", has_many: "Moderators", key: "object_id", where: { accepted: true, object_type: 2}}

    {"user", belongs_to: "Users"}
    {"category_group_categories", has_many: "CategoryGroupCategories"}
  }

  allowed_to_moderate: (user, ignore_admin=false) =>
    return nil unless user
    return true if not ignore_admin and user\is_admin!
    return true if user.id == @user_id

    if mod = @find_moderator user
      return true if mod.accepted

    false

  allowed_to_view: (user) =>
    return true if @allowed_to_edit user
    return false if @find_ban user
    true


  allowed_to_edit: (user) =>
    return nil unless user
    return true if user\is_admin!
    return true if user.id == @user_id
    false

  find_ban: (user) =>
    return nil unless user
    import Bans from require "community.models"
    Bans\find_for_object @, user


  find_moderator: (user) =>
    return nil unless user

    import Moderators from require "community.models"
    Moderators\find {
      object_type: Moderators.object_types.category_group
      object_id: @id
      user_id: user.id
    }

  get_categories_paginated: (opts={}) =>
    import Categories from require "community.models"

    fields = opts.fields
    prepare_results = opts.prepare_results

    opts.prepare_results = (cgcs)->
      Categories\include_in cgcs, "category_id", :fields
      categories = [cgc.category for cgc in *cgcs]

      if prepare_results
        prepare_results categories

      categories

    opts.fields = nil
    @get_category_group_categories_paginated opts

  set_categories: (categories) =>
    import Categories from require "community.models"

    to_add = {}

    ids = @get_category_group_categories_paginated(fields: "category_id")\get_all!
    ids = {cgc.category_id, 1 for cgc in *ids}

    for c in *categories
      if ids[c.id]
        ids[c.id] -= 1
      else
        table.insert to_add, c

    to_remove = [id for id, count in pairs ids when count == 1]
    to_remove = Categories\find_all to_remove

    for category in *to_remove
      @remove_category category

    for category in *to_add
      @add_category category

    true

  add_category: (category) =>
    import CategoryGroupCategories from require "community.models"

    group_category = CategoryGroupCategories\create {
      category_id: category.id
      category_group_id: @id
    }

    if group_category
      @update categories_count: db.raw "categories_count + 1"
      true

  remove_category: (category) =>
    import CategoryGroupCategories from require "community.models"

    group_category = CategoryGroupCategories\find {
      category_id: category.id
      category_group_id: @id
    }

    if group_category and group_category\delete!
      @update categories_count: db.raw "categories_count - 1"
      true

  notification_target_users: =>
    { @get_user! }


