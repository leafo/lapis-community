local db = require("lapis.db")
local Model
Model = require("community.model").Model
local preload
preload = require("lapis.db.model").preload
local Votes
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
    delete = function(self)
      local deleted, res = _class_0.__parent.__base.delete(self, db.raw("*"))
      if res and res[1] then
        local deleted_vote = self.__class:load(res[1])
        deleted_vote:decrement()
      end
      return deleted
    end,
    name = function(self)
      return self.positive and "up" or "down"
    end,
    trigger_vote_callback = function(self, kind)
      local object = self:get_object()
      if object.on_vote_callback then
        return object:on_vote_callback(kind, self)
      end
    end,
    increment = function(self)
      if self.counted == false then
        return 
      end
      local CommunityUsers
      CommunityUsers = require("community.models").CommunityUsers
      CommunityUsers:increment(self.user_id, "votes_count", 1)
      return self:trigger_vote_callback("increment")
    end,
    decrement = function(self)
      if self.counted == false then
        return 
      end
      local CommunityUsers
      CommunityUsers = require("community.models").CommunityUsers
      CommunityUsers:increment(self.user_id, "votes_count", -1)
      return self:trigger_vote_callback("decrement")
    end,
    update_counted = function(self, counted)
      assert(type(counted) == "boolean", "expected boolean for counted")
      local res = db.update(self.__class:table_name(), {
        counted = counted
      }, {
        user_id = self.user_id,
        object_type = self.object_type,
        object_id = self.object_id,
        counted = not counted
      })
      if res.affected_rows and res.affected_rows > 0 then
        self.counted = true
        if counted then
          self:increment()
        else
          self:decrement()
        end
        self.counted = counted
        return true
      end
    end,
    score_adjustment = function(self)
      return self.score or 1
    end,
    base_and_adjustment = function(self, object)
      if object == nil then
        object = self:get_object()
      end
      assert(self.object_type == self.__class:object_type_for_object(object), "invalid object type")
      assert(self.object_id == object.id, "invalid object id")
      local up_score = object.up_votes_count or 0
      local down_score = object.down_votes_count or 0
      local adjustment = self:score_adjustment()
      if self.counted then
        if self.positive then
          up_score = up_score - adjustment
        else
          down_score = down_score - adjustment
        end
      end
      if not (self.positive) then
        adjustment = -adjustment
      end
      return up_score, down_score, adjustment
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "Votes",
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
  self.primary_key = {
    "user_id",
    "object_type",
    "object_id"
  }
  self.relations = {
    {
      "user",
      belongs_to = "Users"
    },
    {
      "object",
      polymorphic_belongs_to = {
        [1] = {
          "post",
          "Posts"
        }
      }
    }
  }
  self.preload_post_votes = function(self, posts, user_id)
    if not (user_id) then
      return 
    end
    local with_votes
    do
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #posts do
        local p = posts[_index_0]
        if p.down_votes_count > 0 or p.up_votes_count > 0 or p.user_id == user_id then
          _accum_0[_len_0] = p:with_viewing_user(user_id)
          _len_0 = _len_0 + 1
        end
      end
      with_votes = _accum_0
    end
    return preload(with_votes, "vote")
  end
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    assert(opts.user_id, "missing user id")
    if not (opts.object_id and opts.object_type) then
      assert(opts.object, "missing vote object")
      opts.object_id = opts.object.id
      opts.object_type = self:object_type_for_object(opts.object)
      opts.object = nil
    end
    opts.object_type = self.object_types:for_db(opts.object_type)
    if not (opts.ip) then
      local CommunityUsers
      CommunityUsers = require("community.models").CommunityUsers
      opts.ip = CommunityUsers:current_ip_address()
    end
    return _class_0.__parent.create(self, opts)
  end
  self.vote = function(self, object, user, positive, opts)
    if positive == nil then
      positive = true
    end
    assert(user, "missing user to create vote from")
    assert(object, "missing object to create vote from")
    local insert_on_conflict_ignore
    insert_on_conflict_ignore = require("community.helpers.models").insert_on_conflict_ignore
    local object_type = self:object_type_for_object(object)
    self:load({
      object_type = object_type,
      object_id = object.id,
      user_id = user.id
    }):delete()
    local CommunityUsers
    CommunityUsers = require("community.models").CommunityUsers
    local cu
    local score
    if opts and opts.score ~= nil then
      score = opts.score
    else
      cu = cu or CommunityUsers:for_user(user)
      score = cu:get_vote_score(object, positive)
    end
    local counted
    if opts and opts.counted ~= nil then
      counted = opts.counted
    else
      cu = cu or CommunityUsers:for_user(user)
      counted = cu:count_vote_for(object)
    end
    local vote = insert_on_conflict_ignore(self, {
      object_type = object_type,
      object_id = object.id,
      user_id = user.id,
      positive = not not positive,
      ip = CommunityUsers:current_ip_address(),
      counted = counted,
      score = score
    })
    if vote then
      vote:increment()
    end
    return vote
  end
  self.unvote = function(self, object, user)
    local object_type = self:object_type_for_object(object)
    return self:load({
      object_type = object_type,
      object_id = object.id,
      user_id = user.id
    }):delete()
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Votes = _class_0
  return _class_0
end
