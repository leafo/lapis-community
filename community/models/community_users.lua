local db = require("lapis.db")
local Model
Model = require("community.model").Model
local CommunityUsers
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
    recount = function(self)
      return self.__class:recount({
        user_id = self.user_id
      })
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
    get_vote_score = function(self, object, positive)
      return 1
    end,
    count_vote_for = function(self, object)
      return object.user_id ~= self.user_id
    end,
    purge_posts = function(self)
      local Posts
      Posts = require("community.models").Posts
      local posts = Posts:select("where user_id = ?", self.user_id)
      for _index_0 = 1, #posts do
        local post = posts[_index_0]
        post:delete("hard")
      end
      self:update({
        posts_count = 0,
        topics_count = 0
      })
      return true
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
    }
  }
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    assert(opts.user_id, "missing user id")
    return Model.create(self, opts)
  end
  self.preload_users = function(self, users)
    self:include_in(users, "user_id", {
      flip = true
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
      local safe_insert
      safe_insert = require("community.helpers.models").safe_insert
      community_user = safe_insert(self, {
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
      posts_count = db.raw("\n        (select count(*) from " .. tostring(db.escape_identifier(Posts:table_name())) .. "\n          where user_id = " .. tostring(id_field) .. "\n          and not deleted and moderation_log_id is null)\n      "),
      votes_count = db.raw("\n        (select count(*) from " .. tostring(db.escape_identifier(Votes:table_name())) .. "\n          where user_id = " .. tostring(id_field) .. ")\n      "),
      topics_count = db.raw("\n        (select count(*) from " .. tostring(db.escape_identifier(Topics:table_name())) .. "\n          where user_id = " .. tostring(id_field) .. "\n          and not deleted)\n      ")
    }, ...)
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  CommunityUsers = _class_0
  return _class_0
end
