local db = require("lapis.db")
local enum
enum = require("lapis.db.model").enum
local Model, VirtualModel
do
  local _obj_0 = require("community.model")
  Model, VirtualModel = _obj_0.Model, _obj_0.VirtualModel
end
local CommunityUsers
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
    with_user = VirtualModel:make_loader("user_users", function(self, user_id)
      assert(user_id, "expecting user id")
      local UserUsers = require("community.models.virtual.user_users")
      return UserUsers:load({
        source_user_id = self.user_id,
        dest_user_id = user_id
      })
    end),
    get_block_recieved = function(self, user)
      return self:with_user(user.id or user.user_id):get_block_recieved()
    end,
    get_block_given = function(self, user)
      return self:with_user(user.id or user.user_id):get_block_given()
    end,
    needs_approval_to_post = function(self, object)
      local _exp_0 = self.posting_permission or self.__class.posting_permissions.default
      if self.__class.posting_permissions.needs_approval == _exp_0 then
        if not (object:allowed_to_moderate(self:get_user())) then
          return true
        end
      end
      local Warnings
      Warnings = require("community.models").Warnings
      local _list_0 = self:get_active_warnings()
      for _index_0 = 1, #_list_0 do
        local warning = _list_0[_index_0]
        if warning.restriction == Warnings.restrictions.pending_posting then
          return true, warning
        end
      end
      return false
    end,
    get_popularity_score = function(self)
      return self.received_up_votes_count - self.received_down_votes_count + self.received_votes_adjustment
    end,
    refresh_received_votes = function(self)
      return self:update({
        received_up_votes_count = db.raw(db.interpolate_query("coalesce((select sum(up_votes_count) from posts where not deleted and user_id = ?), 0)", self.user_id)),
        received_down_votes_count = db.raw(db.interpolate_query("coalesce((select sum(down_votes_count) from posts where not deleted and user_id = ?), 0)", self.user_id))
      }, {
        timestamp = false
      })
    end,
    allowed_to_post = function(self, object)
      local _exp_0 = self.posting_permission or self.__class.posting_permissions.default
      if self.__class.posting_permissions.blocked == _exp_0 then
        return false
      elseif self.__class.posting_permissions.only_own == _exp_0 then
        if not (object:allowed_to_moderate(self:get_user())) then
          return false
        end
      end
      local Warnings
      Warnings = require("community.models").Warnings
      local _list_0 = self:get_active_warnings()
      for _index_0 = 1, #_list_0 do
        local warning = _list_0[_index_0]
        if warning.restriction == Warnings.restrictions.block_posting then
          if object:allowed_to_moderate(self:get_user()) then
            break
          end
          return false, "your account has an active warning", warning
        end
      end
      return true
    end,
    recount = function(self)
      self.__class:recount({
        user_id = self.user_id
      })
      return self:refresh()
    end,
    increment = function(self, field, amount)
      if amount == nil then
        amount = 1
      end
      return self:update({
        [field] = db.raw(db.interpolate_query(tostring(db.escape_identifier(field)) .. " + ?", amount))
      }, {
        timestamp = false
      })
    end,
    increment_from_post = function(self, post, created_topic)
      if created_topic == nil then
        created_topic = false
      end
      return self:update({
        posts_count = db.raw("posts_count + 1"),
        topics_count = (function()
          if created_topic then
            return db.raw("topics_count + 1")
          end
        end)(),
        recent_posts_count = db.raw(db.interpolate_query("(case when last_post_at + ?::interval >= now() at time zone 'utc' then recent_posts_count else 0 end) + 1", self.__class.recent_threshold)),
        last_post_at = db.raw("date_trunc('second', now() at time zone 'utc')")
      }, {
        timestamp = false
      })
    end,
    get_vote_score = function(self, object, positive)
      return 1
    end,
    count_vote_for = function(self, object)
      return object.user_id ~= self.user_id
    end,
    purge_reports = function(self)
      local PostReports
      PostReports = require("community.models").PostReports
      local OrderedPaginator
      OrderedPaginator = require("lapis.db.pagination").OrderedPaginator
      local count = 0
      local pager = OrderedPaginator(PostReports, "id", "where user_id = ?", self.user_id, {
        per_page = 1000
      })
      for report in pager:each_item() do
        if report:delete() then
          count = count + 1
        end
      end
      return count
    end,
    purge_votes = function(self)
      local Votes
      Votes = require("community.models").Votes
      local count = 0
      local OrderedPaginator
      OrderedPaginator = require("lapis.db.pagination").OrderedPaginator
      local pager = OrderedPaginator(Votes, {
        "object_type",
        "object_id"
      }, "where user_id = ?", self.user_id, {
        per_page = 1000
      })
      for vote in pager:each_item() do
        if vote:delete() then
          count = count + 1
        end
      end
      return count
    end,
    purge_posts = function(self)
      local Posts
      Posts = require("community.models").Posts
      local count = 0
      local OrderedPaginator
      OrderedPaginator = require("lapis.db.pagination").OrderedPaginator
      local pager = OrderedPaginator(Posts, {
        "id"
      }, "where user_id = ?", self.user_id, {
        per_page = 1000
      })
      for post in pager:each_item() do
        if post:delete("hard") then
          count = count + 1
        end
      end
      return count
    end,
    posting_rate = function(self, minutes)
      assert(type(minutes) == "number" and minutes > 0)
      local date = require("date")
      if not (self.last_post_at) then
        return 0
      end
      local since_last_post = date.diff(date(true), date(self.last_post_at)):spanminutes()
      if since_last_post > minutes then
        return 0
      end
      local ActivityLogs
      ActivityLogs = require("community.models").ActivityLogs
      local logs = ActivityLogs:select("where user_id = ? and\n        created_at >= (now() at time zone 'utc' - ?::interval) and\n        (action, object_type) in ?\n      order by id desc", self.user_id, tostring(minutes) .. " minutes", db.list({
        db.list({
          ActivityLogs.actions.post.create,
          ActivityLogs.object_types.post
        }),
        db.list({
          ActivityLogs.actions.topic.create,
          ActivityLogs.object_types.topic
        })
      }, {
        fields = "id"
      }))
      return #logs / minutes
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "CommunityUsers",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.timestamp = true
  self.primary_key = "user_id"
  self.current_ip_address = function(self)
    return ngx and ngx.var.remote_addr
  end
  self.posting_permissions = enum({
    default = 1,
    only_own = 2,
    blocked = 3,
    needs_approval = 4
  })
  self.recent_threshold = "10 minutes"
  self.table_name = function(self)
    local prefix_table
    prefix_table = require("community.model").prefix_table
    local name = prefix_table("users")
    self.table_name = function()
      return name
    end
    return name
  end
  self.relations = {
    {
      "user",
      belongs_to = "Users"
    },
    {
      "all_warnings",
      has_many = "warnings",
      key = "user_id",
      order = "id asc"
    },
    {
      "active_warnings",
      has_many = "warnings",
      key = "user_id",
      order = "id asc",
      where = db.clause({
        "expires_at IS NULL or now() at time zone 'utc' < expires_at"
      })
    },
    {
      "pending_posts",
      has_many = "PendingPosts",
      key = "user_id",
      order = "id asc"
    }
  }
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    assert(opts.user_id, "missing user id")
    if opts.posting_permission then
      opts.posting_permission = self.posting_permissions:for_db(opts.posting_permission)
    end
    return _class_0.__parent.create(self, opts)
  end
  self.preload_users = function(self, users)
    self:include_in(users, {
      user_id = "id"
    })
    return users
  end
  self.for_user = function(self, user_id)
    if type(user_id) == "table" then
      user_id = user_id.id
    end
    local community_user = self:find({
      user_id = user_id
    })
    if not (community_user) then
      local insert_on_conflict_ignore
      insert_on_conflict_ignore = require("community.helpers.models").insert_on_conflict_ignore
      community_user = insert_on_conflict_ignore(self, {
        user_id = user_id
      })
      community_user = community_user or self:find({
        user_id = user_id
      })
    end
    return community_user
  end
  self.recount = function(self, ...)
    local Topics, Posts, Votes
    do
      local _obj_0 = require("community.models")
      Topics, Posts, Votes = _obj_0.Topics, _obj_0.Posts, _obj_0.Votes
    end
    local id_field = tostring(db.escape_identifier(self:table_name())) .. ".user_id"
    return db.update(self:table_name(), {
      posts_count = db.raw("\n        (select count(*) from " .. tostring(db.escape_identifier(Posts:table_name())) .. " as posts\n          where user_id = " .. tostring(id_field) .. "\n          and not deleted and moderation_log_id is null)\n      "),
      votes_count = db.raw("\n        (select count(*) from " .. tostring(db.escape_identifier(Votes:table_name())) .. "\n          where user_id = " .. tostring(id_field) .. ")\n      "),
      topics_count = db.raw("\n        (select count(*) from " .. tostring(db.escape_identifier(Topics:table_name())) .. "\n          where user_id = " .. tostring(id_field) .. "\n          and not deleted and not permanent)\n      ")
    }, ...)
  end
  self.find_users_by_name = function(self, names)
    local Users
    Users = require("models").Users
    return Users:find_all(names, {
      key = "username"
    })
  end
  self.increment = function(self, user_id, field, amount)
    assert(user_id, "missing user_id")
    assert(field, "missing field")
    assert(type(amount) == "number", "missing or invalid number")
    local insert_on_conflict_update
    insert_on_conflict_update = require("community.helpers.models").insert_on_conflict_update
    return insert_on_conflict_update(self, {
      user_id = user_id
    }, {
      [field] = amount
    }, {
      [field] = db.raw(tostring(db.escape_identifier(self:table_name())) .. "." .. tostring(db.escape_identifier(field)) .. " + excluded." .. tostring(db.escape_identifier(field)))
    })
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  CommunityUsers = _class_0
  return _class_0
end
