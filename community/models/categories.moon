db = require "lapis.db"
import enum from require "lapis.db.model"
import Model from require "community.model"

import slugify from require "lapis.util"

parent_enum = (property_name, default, opts) =>
  enum_name = next opts
  @["default_#{property_name}"] = default
  @[enum_name] = opts[enum_name]

  method_name = "get_#{property_name}"

  @__base[method_name] = =>
    if t = @[property_name]
      t
    elseif @parent_category_id
      parent = @get_parent_category!
      parent[method_name] parent
    else
      @@[enum_name][default]

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_categories (
--   id integer NOT NULL,
--   title character varying(255),
--   slug character varying(255),
--   user_id integer,
--   parent_category_id integer,
--   last_topic_id integer,
--   topics_count integer DEFAULT 0 NOT NULL,
--   deleted_topics_count integer DEFAULT 0 NOT NULL,
--   views_count integer DEFAULT 0 NOT NULL,
--   short_description text,
--   description text,
--   rules text,
--   membership_type integer,
--   voting_type integer,
--   archived boolean DEFAULT false NOT NULL,
--   hidden boolean DEFAULT false NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL,
--   category_groups_count integer DEFAULT 0 NOT NULL,
--   approval_type smallint,
--   "position" integer DEFAULT 0 NOT NULL,
--   directory boolean DEFAULT false NOT NULL,
--   topic_posting_type smallint
-- );
-- ALTER TABLE ONLY community_categories
--   ADD CONSTRAINT community_categories_pkey PRIMARY KEY (id);
-- CREATE INDEX community_categories_parent_category_id_position_idx ON community_categories USING btree (parent_category_id, "position") WHERE (parent_category_id IS NOT NULL);
--
class Categories extends Model
  @timestamp: true

  parent_enum @, "membership_type", "public", {
    membership_types: enum {
      public: 1
      members_only: 2
    }
  }

  parent_enum @, "topic_posting_type", "everyone", {
    topic_posting_types: enum {
      everyone: 1
      members_only: 2
      moderators_only: 3
    }
  }

  parent_enum @, "voting_type", "up_down", {
    voting_types: enum {
      up_down: 1
      up: 2
      disabled: 3
    }
  }

  parent_enum @, "approval_type", "none", {
    approval_types: enum {
      none: 1
      pending: 2
    }
  }

  @relations: {
    -- TODO: don't hardcode 1
    -- TODO: rename to accepted_moderators
    {"moderators", has_many: "Moderators", key: "object_id", where: { accepted: true, object_type: 1}}

    {"category_group_category", has_one: "CategoryGroupCategories"}
    {"user", belongs_to: "Users"}
    {"last_topic", belongs_to: "Topics"}
    {"parent_category", belongs_to: "Categories"}
    {"tags", has_many: "CategoryTags", order: "tag_order asc"}
  }

  @next_position: (parent_id) =>
    db.raw db.interpolate_query "
     (select coalesce(max(position), 0) from #{db.escape_identifier @table_name!}
       where parent_category_id = ?) + 1
    ", parent_id

  @create: (opts={}) =>
    if opts.membership_type
      opts.membership_type = @membership_types\for_db opts.membership_type

    if opts.voting_type
      opts.voting_type = @voting_types\for_db opts.voting_type

    if opts.approval_type
      opts.approval_type = @approval_types\for_db opts.approval_type

    if opts.title
      opts.slug or= slugify opts.title

    if opts.parent_category_id and not opts.position
      opts.position = @next_position opts.parent_category_id

    Model.create @, opts

  @recount: =>
    import Topics from require "community.models"
    db.update @table_name!, {
      topics_count: db.raw "
        (select count(*) from #{db.escape_identifier Topics\table_name!}
          where category_id = #{db.escape_identifier @table_name!}.id)
      "
    }

  @preload_ancestors: (categories) =>
    categories_by_id = {c.id, c for c in *categories}

    has_parents = false

    parent_ids = for c in *categories
      continue unless c.parent_category_id
      has_parents = true

      continue if categories_by_id[c.parent_category_id]
      c.parent_category_id

    return unless has_parents

    if next parent_ids
      tname = db.escape_identifier @@table_name!
      res = db.query "
        with recursive nested as (
          (select * from #{tname} where id in ?)
          union
          select pr.* from #{tname} pr, nested
            where pr.id = nested.parent_category_id
        )
        select * from nested
      ", db.list parent_ids

      for category in *res
        category = @@load category
        categories_by_id[category.id] or= category

    -- now build all the ancestors
    for _, category in pairs categories_by_id
      continue unless category.parent_category_id
      category.ancestors = {}
      current = categories_by_id[category.parent_category_id]
      while current
        table.insert category.ancestors, current
        current = categories_by_id[current.parent_category_id]

    true

  @preload_bans: (categories, user) =>
    return unless user
    return unless next categories

    -- preload anecestors where necessary
    @preload_ancestors [c for c in *categories when not c.ancestors]

    categories_by_id = {}
    for c in *categories
      categories_by_id[c.id] = c
      for ancestor in *c\get_ancestors!
        categories_by_id[ancestor.id] or= ancestor

    category_ids = [id for id in pairs categories_by_id]

    import Bans from require "community.models"
    bans = Bans\select "
      where banned_user_id = ? and object_type = ? and object_id in ?
    ", user.id, Bans.object_types.category, db.list category_ids

    bans_by_category_id = {b.object_id, b for b in *bans}

    for _, category in pairs categories_by_id
      category.user_bans or= {}
      category.user_bans[user.id] = bans_by_category_id[category.id] or false

    true

  get_category_group: =>
    return unless @category_groups_count and @category_groups_count > 0
    -- TODO: this doesn't support multiple
    if cgc = @get_category_group_category!
      cgc\get_category_group!

  allowed_to_post_topic: (user) =>
    return false unless user
    return false if @archived
    return false if @hidden
    return false if @directory

    switch @get_topic_posting_type!
      when @@topic_posting_types.everyone
        @allowed_to_view user
      when @@topic_posting_types.members_only
        return true if @allowed_to_moderate user
        @is_member user
      when @@topic_posting_types.moderators_only
        @allowed_to_moderate user
      else
        error "unknown topic posting type"

  allowed_to_view: (user) =>
    return false if @hidden

    switch @@membership_types[@get_membership_type!]
      when "public"
        nil
      when "members_only"
        return false unless user
        return true if @allowed_to_moderate user
        return false unless @is_member user

    return false if @get_ban user

    if category_group = @get_category_group!
      return false unless category_group\allowed_to_view user

    true

  allowed_to_vote: (user, direction) =>
    return false unless user
    return true if direction == "remove"

    switch @get_voting_type!
      when @@voting_types.up_down
        true
      when @@voting_types.up
        direction == "up"
      else
        false

  allowed_to_edit: (user) =>
    return nil unless user
    return true if user\is_admin!
    return true if user.id == @user_id
    false

  allowed_to_edit_moderators: (user) =>
    return nil unless user
    return true if user\is_admin!
    return true if user.id == @user_id
    if mod = @find_moderator user, accepted: true, admin: true
      return true

    false

  allowed_to_edit_members: (user) =>
    return nil unless user
    return @allowed_to_moderate user

  allowed_to_moderate: (user, ignore_admin=false) =>
    return nil unless user
    return true if not ignore_admin and user\is_admin!
    return true if user.id == @user_id

    if mod = @find_moderator user, accepted: true
      return true

    if group = @get_category_group!
      return true if group\allowed_to_moderate user

    false

  find_moderator: (user, clause) =>
    return nil unless user

    import Moderators from require "community.models"

    opts = {
      object_type: Moderators.object_types.category
      object_id: @parent_category_id and db.list(@get_category_ids!) or @id
      user_id: user.id
    }

    if clause
      for k,v in pairs clause
        opts[k] = v

    Moderators\find opts

  is_member: (user) =>
    @find_member user, accepted: true

  find_member: (user, clause) =>
    return nil unless user
    import CategoryMembers from require "community.models"

    opts = {
      category_id: @parent_category_id and db.list(@get_category_ids!) or @id
      user_id: user.id
    }

    if clause
      for k,v in pairs clause
        opts[k] = v

    -- TODO: this returns a random category object, might want to make it
    -- return the closest category in tree
    CategoryMembers\find opts

  find_ban: (user) =>
    return nil unless user
    import Bans from require "community.models"

    Bans\find {
      object_type: Bans.object_types.category
      object_id: @parent_category_id and db.list(@get_category_ids!) or @id
      banned_user_id: user.id
    }

  get_ban: (user) =>
    return nil unless user

    @user_bans or= {}
    ban = @user_bans[user.id]

    if ban != nil
      return ban

    @user_bans[user.id] = @find_ban(user) or false
    @user_bans[user.id]

  get_order_ranges: (status="default") =>
    import Topics from require "community.models"
    status = Topics.statuses\for_db status

    res = db.query "
      select sticky, min(category_order), max(category_order)
      from #{db.escape_identifier Topics\table_name!}
      where category_id = ? and status = ? and not deleted
      group by sticky
    ", @id, status

    ranges = {
      sticky: {}
      regular: {}
    }

    for {:sticky, :min, :max} in *res
      r = ranges[sticky and "sticky" or "regular"]
      r.min = min
      r.max = max

    ranges

  available_vote_types: =>
    switch @get_voting_type!
      when @@voting_types.up_down
        { up: true, down: true }
      when @@voting_types.up
        { up: true }
      else
        {}

  refresh_last_topic: =>
    import Topics from require "community.models"

    @update {
      last_topic_id: db.raw db.interpolate_query "(
        select id from #{db.escape_identifier Topics\table_name!}
        where
          category_id = ? and
          not deleted and
          status = ?
        order by category_order desc
        limit 1
      )", @id, Topics.statuses.default
    }, timestamp: false

  increment_from_topic: (topic) =>
    assert topic.category_id == @id, "topic does not belong to category"

    import clear_loaded_relation from require "lapis.db.model.relations"
    clear_loaded_relation @, "last_topic"

    @update {
      topics_count: db.raw "topics_count + 1"
      last_topic_id: topic.id
    }, timestamp: false

  increment_from_post: (post) =>
    import CategoryPostLogs from require "community.models"
    CategoryPostLogs\log_post post

    @update {
      last_topic_id: post.topic_id
    }, timestamp: false

  notification_target_users: =>
    { @get_user! }

  get_category_ids: =>
    if @parent_category_id
      ids = [c.id for c in *@get_ancestors!]
      table.insert ids, @id
      ids
    else
      { @id }

  get_parent_category: =>
    @get_ancestors![1]

  get_ancestors: =>
    return {} unless @parent_category_id

    unless @ancestors
      @@preload_ancestors { @ }

    @ancestors

  get_children: (opts) =>
    return @children if @children

    sorter = (a,b) -> a.position < b.position

    import NestedOrderedPaginator from require "community.model"
    pager = NestedOrderedPaginator @@, "position", [[
      where parent_category_id = ?
    ]], @id, {
      prepare_results: opts and opts.prepare_results
      per_page: 1000
      parent_field: "parent_category_id"
      sort: (cats) -> table.sort cats, sorter
      is_top_level_item: (item) ->
        item.parent_category_id == @id
    }

    @children = pager\get_page!
    @children

  get_flat_children: (...) =>
    @get_children ...
    flat = {}
    append_children = (cat) ->
      for c in *cat.children
        table.insert flat, c
        if c.children and next c.children
          append_children c

    append_children @
    flat

  find_last_seen_for_user: (user) =>
    return unless user
    return unless @last_topic_id

    import UserCategoryLastSeens from require "community.models"
    last_seen = UserCategoryLastSeens\find {
      user_id: user.id
      category_id: @id
    }

    if last_seen
      last_seen.category = @
      last_seen.user = user

    last_seen

  -- this assumes UserCategoryLastSeens and last topic has been preloaded
  has_unread: (user) =>
    return unless user

    return unless @user_category_last_seen
    return unless @last_topic_id

    assert @user_category_last_seen.user_id == user.id,
      "unexpected user for last seen"

    @user_category_last_seen.category_order < @get_last_topic!.category_order

  set_seen: (user) =>
    return unless user
    return unless @last_topic_id

    import upsert from require "community.helpers.models"
    import UserCategoryLastSeens from require "community.models"

    last_topic = @get_last_topic!

    upsert UserCategoryLastSeens, {
      user_id: user.id
      category_id: @id
      topic_id: last_topic.id
      category_order: last_topic.category_order
    }

  parse_tags: (str="") =>
    tags_by_slug = {t.slug, t for t in *@get_tags!}
    import trim from require "lapis.util"
    parsed = [trim s for s in str\gmatch "[^,]+"]
    seen = {}
    parsed = for t in *parsed
      t = tags_by_slug[t]
      continue unless t
      continue if seen[t.slug]
      seen[t.slug] = true
      t

    parsed

  should_log_posts: =>
    @directory


