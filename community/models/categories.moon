db = require "lapis.db"
import enum from require "lapis.db.model"
import Model, VirtualModel from require "community.model"

import relation_is_loaded from require "lapis.db.model.relations"

import slugify from require "lapis.util"

import preload from require "lapis.db.model"

VOTE_TYPES_UP = { up: true }
VOTE_TYPES_BOTH = { up: true, down: true }
VOTE_TYPES_NONE = { }

parent_enum = (property_name, default, opts) =>
  enum_name = next opts
  default_key = "default_#{property_name}"

  @[default_key] = default
  @[enum_name] = opts[enum_name]

  method_name = "get_#{property_name}"

  @__base[method_name] = =>
    if t = @[property_name]
      t
    elseif @parent_category_id
      parent = @get_parent_category!
      parent[method_name] parent
    else
      @@[enum_name]\for_db @@[default_key]

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
--   topic_posting_type smallint,
--   category_order_type smallint DEFAULT 1 NOT NULL,
--   data jsonb
-- );
-- ALTER TABLE ONLY community_categories
--   ADD CONSTRAINT community_categories_pkey PRIMARY KEY (id);
-- CREATE INDEX community_categories_parent_category_id_position_idx ON community_categories USING btree (parent_category_id, "position") WHERE (parent_category_id IS NOT NULL);
--
class Categories extends Model
  @timestamp: true
  @score_starting_date: 1134028003

  class CategoryViewers extends VirtualModel
    @primary_key: {"categroy_id", "user_id"}

    @relations: {
      {"moderator", has_one: "Moderators", key: {
        user_id: "user_id"
        object_id: "category_id"
      }, where: {
        object_type: 1
      }}

      {"ban", has_one: "Bans", key: {
        banned_user_id: "user_id"
        object_id: "category_id"
      }, where: {
        object_type: 1
      }}

      {"subscription", has_one: "Subscriptions", key: {
        user_id: "user_id"
        object_id: "category_id"
      }, where: {
        object_type: 2
      }}

      {"member", has_one: "CategoryMembers", key: {"user_id", "category_id"}}

      {"last_seen", has_one: "UserCategoryLastSeens", key: {"user_id", "category_id"} }
    }

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
      up_down_first_post: 4
    }
  }

  parent_enum @, "approval_type", "none", {
    approval_types: enum {
      none: 1
      pending: 2
    }
  }

  @category_order_types: enum {
    post_date: 1
    topic_score: 2
  }

  @relations: {
    {"moderators", has_many: "Moderators", key: "object_id", where: { object_type: 1 } }

    {"category_group_category", has_one: "CategoryGroupCategories"}
    {"user", belongs_to: "Users"}
    {"last_topic", belongs_to: "Topics"}
    {"parent_category", belongs_to: "Categories"}
    {"tags", has_many: "CategoryTags", order: "tag_order asc"}
    {"subscriptions", has_many: "Subscriptions", key: "object_id", where: {object_type: 2}}
    {"topics", has_many: "Topics", order: "category_order desc"}

    -- this includes all moderators in the hierarchy
    -- TODO: this should also included all moderators from categroy groups
    {"active_moderators", fetch: =>
      import Moderators from require "community.models"
      import encode_clause from require "lapis.db"
      Moderators\select "where #{encode_clause {
        accepted: true
        object_type: Moderators.object_types.category
        object_id: @parent_category_id and db.list(@get_category_ids!) or @id
      }}"
    }
  }

  @next_position: (parent_id) =>
    db.raw db.interpolate_query "
     (select coalesce(max(position), 0) from #{db.escape_identifier @table_name!}
       where parent_category_id = ?) + 1
    ", parent_id

  @create: (opts={}) =>
    if opts.membership_type and opts.membership_type != db.NULL
      opts.membership_type = @membership_types\for_db opts.membership_type

    if opts.voting_type and opts.voting_type != db.NULL
      opts.voting_type = @voting_types\for_db opts.voting_type

    if opts.approval_type and opts.approval_type != db.NULL
      opts.approval_type = @approval_types\for_db opts.approval_type

    if opts.category_order_type and opts.category_order_type != db.NULL
      opts.category_order_type = @category_order_types\for_db opts.category_order_type

    if opts.topic_posting_type and opts.topic_posting_type != db.NULL
      opts.topic_posting_type = @topic_posting_types\for_db opts.topic_posting_type

    if opts.title
      opts.slug or= slugify opts.title

    if opts.parent_category_id and not opts.position
      opts.position = @next_position opts.parent_category_id

    super opts

  @recount: (...) =>
    import Topics, CategoryGroupCategories from require "community.models"

    id_field = "#{db.escape_identifier @table_name!}.id"

    db.update @table_name!, {
      topics_count: db.raw "(
        select count(*) from #{db.escape_identifier Topics\table_name!}
          where category_id = #{id_field}
      )"
      deleted_topics_count: db.raw "(
        select count(*) from #{db.escape_identifier Topics\table_name!}
          where category_id = #{id_field}
          and deleted
      )"
      category_groups_count: db.raw "(
        select count(*) from #{db.escape_identifier CategoryGroupCategories\table_name!}
          where category_id = #{id_field}
      )"
    }, ...

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

    @preload_ancestors [c for c in *categories when not c.ancestors]

    all_viewers = {}
    for category in *categories
      table.insert all_viewers, category\with_user(user.id)
      for parent_category in *category\get_ancestors!
        table.insert all_viewers, parent_category\with_user(user.id)

    preload all_viewers, "ban"
    true

  with_user: VirtualModel\make_loader "category_viewers", (user_id) =>
    assert user_id, "expecting user id"
    CategoryViewers\load {
      user_id: user_id
      category_id: @id
    }

  get_category_group: =>
    return unless @category_groups_count and @category_groups_count > 0
    -- TODO: this doesn't support multiple
    if cgc = @get_category_group_category!
      cgc\get_category_group!

  -- NOTE: there are different stanges of posting permission checks. This one
  -- is focused on global check and the posting type of the category
  allowed_to_post_topic: (user, req) =>
    return false unless user
    return false if @archived
    return false if @hidden
    return false if @directory

    switch @get_topic_posting_type!
      when @@topic_posting_types.everyone
        @allowed_to_view user, req
      when @@topic_posting_types.members_only
        return true if @allowed_to_moderate user
        @is_member user
      when @@topic_posting_types.moderators_only
        @allowed_to_moderate user
      else
        error "unknown topic posting type"

  allowed_to_view: (user, req) =>
    return false if @hidden

    switch @@membership_types[@get_membership_type!]
      when "public"
        nil
      when "members_only"
        return false unless user
        return true if @allowed_to_moderate user
        return false unless @is_member user

    return false if @find_ban user

    if category_group = @get_category_group!
      return false unless category_group\allowed_to_view user, req

    true

  allowed_to_vote: (user, direction, post) =>
    return false unless user
    return true if direction == "remove"

    switch @get_voting_type!
      when @@voting_types.up_down
        true
      when @@voting_types.up
        direction == "up"
      when @@voting_types.up_down_first_post
        if post and post\is_topic_post!
          true
      else
        false

  allowed_to_edit: (user) =>
    return nil unless user
    return true if user\is_admin!
    return true if user.id == @user_id

    if mod = @find_moderator user, accepted: true, admin: true
      if mod\can_moderate!
        return true

    false

  allowed_to_edit_moderators: (user) =>
    return true if @allowed_to_edit user
    if mod = @find_moderator user, accepted: true, admin: true
      if mod\can_moderate!
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
      if mod\can_moderate!
        return true

    if group = @get_category_group!
      return true if group\allowed_to_moderate user

    false

  -- return category_user virtual models for the category hierarchy
  preloaded_category_user_chain: (user, relation) =>
    category_chain = { @, unpack @get_ancestors! }

    if relation
      to_preload = for c in *category_chain
        v = c\with_user user.id
        continue if relation_is_loaded v, relation
        v

      preload to_preload, relation

    [c\with_user user.id for c in *category_chain]


  -- search up the ancestor chain for the closest moderator that matches the filter
  find_moderator: (user, filter) =>
    return nil unless user

    for v in *@preloaded_category_user_chain user, "moderator"
      moderator = v\get_moderator!
      continue unless moderator

      if filter
        pass = true

        for k, v in pairs filter
          if moderator[k] != v
            pass = false
            break

        continue unless pass

      return moderator


    nil

  is_member: (user) =>
    @find_member user, accepted: true

  find_member: (user, filter) =>
    return nil unless user
    for v in *@preloaded_category_user_chain user, "member"
      member = v\get_member!
      continue unless member

      if filter
        pass = true
        for k,v in pairs filter
          unless member[k] == v
            pass = false
            break

        continue unless pass

      return member

  -- search up ancestor chain for the closest ban
  find_ban: (user) =>
    return nil unless user
    for v in *@preloaded_category_user_chain user, "ban"
      if ban = v\get_ban!
        return ban

    nil

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

  available_vote_types: (post) =>
    switch @get_voting_type!
      when @@voting_types.up_down
        VOTE_TYPES_BOTH
      when @@voting_types.up
        VOTE_TYPES_UP
      when @@voting_types.up_down_first_post
        if post and post\is_topic_post!
          VOTE_TYPES_BOTH
        else
          VOTE_TYPES_NONE
      else
        VOTE_TYPES_NONE

  refresh_topic_category_order: =>
    switch @category_order_type
      when @@category_order_types.post_date
        @refresh_topic_category_order_by_post_date()
      when @@category_order_types.topic_score
        @refresh_topic_category_order_by_topic_score()
      else
        error "unknown category order type"

  topic_score_bucket_size: =>
    45000

  refresh_topic_category_order_by_topic_score: =>
    import Topics, Posts from require "community.models"

    tname = db.escape_identifier Topics\table_name!
    posts_tname = db.escape_identifier Posts\table_name!

    start = @@score_starting_date
    time_bucket = @topic_score_bucket_size!

    score_query = "(
      select up_votes_count - down_votes_count + rank_adjustment
      from #{posts_tname} where topic_id = #{tname}.id and post_number = 1 and depth = 1 and parent_post_id is null
    )"

    db.query "
      update #{tname}
      set category_order =
        (
          (extract(epoch from created_at) - ?) / ? +
          2 * (case when #{score_query} > 0 then 1 else -1 end) * log(greatest(abs(#{score_query}) + 1, 1))
        ) * 1000
      where category_id = ?
    ", start, time_bucket, @id

  refresh_topic_category_order_by_post_date: =>
    import Topics, Posts from require "community.models"
    tname = db.escape_identifier Topics\table_name!
    posts_tname = db.escape_identifier Posts\table_name!

    db.query "
      update #{tname}
      set category_order = k.category_order
      from (
        select id, row_number() over (order by last_post_at asc) as category_order
        from
        (
          select
            inside.id,
            coalesce(
              (select created_at from #{posts_tname} as posts where posts.id = last_post_id),
              inside.created_at
            ) as last_post_at
          from #{tname} as inside where category_id = ?
        ) as t
      ) k
      where #{tname}.id = k.id
    ", @id

    @refresh_last_topic!

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

    @clear_loaded_relation "last_topic"
    @update {
      topics_count: db.raw "topics_count + 1"
      last_topic_id: topic.id
    }, timestamp: false

  increment_from_post: (post) =>
    if post\is_moderation_event!
      return

    import CategoryPostLogs from require "community.models"
    CategoryPostLogs\log_post post

    unless @last_topic_id == post.topic_id
      @clear_loaded_relation "last_topic"
      @update {
        last_topic_id: post.topic_id
      }, timestamp: false

  -- includes the owners of each category along with any category subscriptions
  -- applied
  notification_target_users: =>
    -- this puts prececence on the nearest categories, an unsub in an inner
    -- category will negate a sub in an outer one
    hierarchy = { @, unpack @get_ancestors! }
    preload hierarchy, "user", subscriptions: "user"

    seen_targets = {}
    subs = {}

    for c in *hierarchy
      for sub in *c\get_subscriptions!
        table.insert subs, sub

    targets = for sub in *subs
      continue if seen_targets[sub.user_id]
      seen_targets[sub.user_id] = true
      continue unless sub.subscribed
      sub\get_user!

    -- add the owners
    for c in *hierarchy
      continue unless c.user_id
      continue if seen_targets[c.user_id]
      table.insert targets, c\get_user!

    targets

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
    return nil unless user

    -- if it's an empty category then we can just assume they have seen nothing
    return nil unless @last_topic_id

    last_seen = @with_user(user.id)\get_last_seen!

    -- just to avoid any addditional queries
    if last_seen
      last_seen.category = @
      last_seen.user = user

    last_seen

  -- this assumes UserCategoryLastSeens and last topic has been preloaded
  has_unread: (user) =>
    if last_seen = @find_last_seen_for_user user
      last_seen.category_order < @get_last_topic!.category_order
    else
      false

  set_seen: (user) =>
    return unless user
    return unless @last_topic_id

    import insert_on_conflict_update from require "community.helpers.models"
    import UserCategoryLastSeens from require "community.models"

    last_topic = @get_last_topic!

    insert_on_conflict_update UserCategoryLastSeens, {
      user_id: user.id
      category_id: @id
    }, {
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

    if next parsed
      parsed

  should_log_posts: =>
    @directory

  find_subscription: (user) =>
    import Subscriptions from require "community.models"
    Subscriptions\find_subscription @, user

  is_subscribed: (user) =>
    if sub = @with_user(user.id)\get_subscription!
      sub\is_subscribed!
    else
      false

  subscribe: (user, req) =>
    import Subscriptions from require "community.models"
    Subscriptions\subscribe @, user, user.id == @user_id

  unsubscribe: (user) =>
    import Subscriptions from require "community.models"
    Subscriptions\unsubscribe @, user, user.id == @user_id

  order_by_score: =>
    @category_order_type == @@category_order_types.topic_score

  order_by_date: =>
    @category_order_type == @@category_order_types.post_date

  -- this is for a brand new topic, so it has no votes and create date is right now
  next_topic_category_order: =>
    import Topics from require "community.models"

    switch @category_order_type
      when @@category_order_types.topic_score
        Topics\calculate_score_category_order 0, db.format_date!, @topic_score_bucket_size!
      when @@category_order_types.post_date
        Topics\update_category_order_sql @id

  update_category_order_type: (category_order) =>
    category_order = @@category_order_types\for_db category_order
    return if category_order == @category_order_type

    @update {
      category_order_type: category_order
    }

    @refresh_topic_category_order!

  -- returns boolean, and potential warning if warning is issued
  topic_needs_approval: (user, topic_params) =>
    return false if @allowed_to_moderate user

    if @get_approval_type! == Categories.approval_types.pending
      return true

    import CommunityUsers from require "community.models"

    if cu = CommunityUsers\for_user user
      needs_approval, warning = cu\need_approval_to_post!
      if needs_approval
        return true, warning

    false

