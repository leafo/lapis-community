db = require "lapis.db"
import enum from require "lapis.db.model"
import Model from require "community.model"

import slugify from require "lapis.util"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_categories (
--   id integer NOT NULL,
--   title character varying(255) NOT NULL,
--   slug character varying(255) NOT NULL,
--   user_id integer,
--   parent_category_id integer,
--   last_topic_id integer,
--   topics_count integer DEFAULT 0 NOT NULL,
--   deleted_topics_count integer DEFAULT 0 NOT NULL,
--   views_count integer DEFAULT 0 NOT NULL,
--   short_description text,
--   description text,
--   rules text,
--   membership_type integer DEFAULT 0 NOT NULL,
--   voting_type integer DEFAULT 0 NOT NULL,
--   archived boolean DEFAULT false NOT NULL,
--   hidden boolean DEFAULT false NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_categories
--   ADD CONSTRAINT community_categories_pkey PRIMARY KEY (id);
--
class Categories extends Model
  @timestamp: true

  @membership_types: enum {
    public: 1
    members_only: 2
  }

  @voting_types: enum {
    up_down: 1
    up: 2
    disabled: 3
  }

  @relations: {
    -- TODO: don't hardcode 1
    -- TODO: rename to accepted_moderators
    {"moderators", has_many: "Moderators", key: "object_id", where: { accepted: true, object_type: 1}}

    {"category_group_category", has_one: "CategoryGroupCategories"}
    {"user", belongs_to: "Users"}
    {"last_topic", belongs_to: "Topics"}
  }

  @create: (opts={}) =>
    assert opts.title, "missing title"
    opts.membership_type = @membership_types\for_db opts.membership_type or "public"
    opts.voting_type = @voting_types\for_db opts.voting_type or "up_down"
    opts.slug or= slugify opts.title

    Model.create @, opts

  @preload_last_topics: (categories) =>
    import Topics from require "community.models"
    Topics\include_in categories, "last_topic_id", {
      as: "last_topic"
    }

  get_category_group: =>
    if cgc = @get_category_group_category!
      cgc\get_category_group!

  allowed_to_post: (user) =>
    return false unless user
    return false if @archived
    return false if @hidden

    @allowed_to_view user

  allowed_to_view: (user) =>
    return false if @hidden

    switch @@membership_types[@membership_type]
      when "public"
        nil
      when "members_only"
        return false unless user
        return true if @allowed_to_moderate user
        return false unless @is_member user

    return false if @find_ban user

    if category_group = @get_category_group!
      return false unless category_group\allowed_to_view user

    true

  allowed_to_vote: (user, direction) =>
    return false unless user
    return true if direction == "remove"

    switch @voting_type
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
    member = @find_member user
    member and member.accepted

  find_member: (user) =>
    -- TODO: make this hierarchy aware
    return nil unless user
    import CategoryMembers from require "community.models"

    CategoryMembers\find {
      category_id: @id
      user_id: user.id
    }

  find_ban: (user) =>
    return nil unless user
    import Bans from require "community.models"
    Bans\find_for_object @, user

  get_order_ranges: =>
    import Topics from require "community.models"

    res = db.query "
      select sticky, min(category_order), max(category_order)
      from #{db.escape_identifier Topics\table_name!}
      where category_id = ? and not deleted
      group by sticky
    ", @id

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
    switch @voting_type
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
        select id from #{db.escape_identifier Topics\table_name!} where category_id = ? and not deleted
        order by category_order desc
        limit 1
      )", @id
    }, timestamp: false

  increment_from_topic: (topic) =>
    assert topic.category_id == @id

    @update {
      topics_count: db.raw "topics_count + 1"
      last_topic_id: topic.id
    }, timestamp: false

  increment_from_post: (post) =>
    @update {
      last_topic_id: post.topic_id
    }, timestamp: false

  @recount: =>
    import Topics from require "community.models"
    db.update @table_name!, {
      topics_count: db.raw "
        (select count(*) from #{db.escape_identifier Topics\table_name!}
          where category_id = #{db.escape_identifier @table_name!}.id)
      "
    }

  notification_target_users: =>
    { @get_user! }

  get_category_ids: =>
    if @parent_category_id
      { @id, unpack [c.id for c in *@get_ancestors!] }
    else
      { @id }

  get_ancestors: =>
    return {} unless @parent_category_id
    unless @ancestors
      tname = db.escape_identifier @@table_name!

      res = db.query "
        with recursive nested as (
          (select * from #{tname} where id = ?)
          union
          select pr.* from #{tname} pr, nested
            where pr.id = nested.parent_category_id
        )
        select * from nested
      ", @parent_category_id

      @ancestors = for category in *res
        @@load category

    @ancestors

