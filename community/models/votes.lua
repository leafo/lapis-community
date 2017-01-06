local db = require("lapis.db")
local Model
Model = require("community.model").Model
local Votes
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
    name = function(self)
      return self.positive and "up" or "down"
    end,
    trigger_vote_callback = function(self, res)
      local object = unpack(res)
      if not (object) then
        return 
      end
      local model = self.__class:model_for_object_type(self.object_type)
      model:load(object)
      if object.on_vote_callback then
        object:on_vote_callback(self)
      end
      return res
    end,
    increment = function(self)
      local model = self.__class:model_for_object_type(self.object_type)
      local counter_name = self:post_counter_name()
      local score = self.score or 1
      if not (self.counted == false) then
        return self:trigger_vote_callback(db.update(model:table_name(), {
          [counter_name] = db.raw(tostring(db.escape_identifier(counter_name)) .. " + " .. tostring(db.escape_literal(score)))
        }, {
          id = self.object_id
        }, db.raw("*")))
      end
    end,
    decrement = function(self)
      local model = self.__class:model_for_object_type(self.object_type)
      local counter_name = self:post_counter_name()
      local score = self.score or 1
      if not (self.counted == false) then
        return self:trigger_vote_callback(db.update(model:table_name(), {
          [counter_name] = db.raw(tostring(db.escape_identifier(counter_name)) .. " - " .. tostring(db.escape_literal(score)))
        }, {
          id = self.object_id
        }, db.raw("*")))
      end
    end,
    updated_counted = function(self, counted)
      local res = db.update(self.__class:table_name(), {
        counted = counted
      }, {
        user_id = self.user_id,
        object_type = self.object_type,
        object_id = self.object_type,
        counted = not counted
      })
      if res.affected_rows and res.affected_rows > 0 then
        if counted then
          return self:increment()
        else
          return self:decrement()
        end
      end
    end,
    post_counter_name = function(self)
      if self.positive then
        return "up_votes_count"
      else
        return "down_votes_count"
      end
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
  self.current_ip_address = function(self)
    return ngx and ngx.var.remote_addr
  end
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
    local posts_with_votes
    do
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #posts do
        local p = posts[_index_0]
        if p.down_votes_count > 0 or p.up_votes_count > 0 then
          _accum_0[_len_0] = p
          _len_0 = _len_0 + 1
        end
      end
      posts_with_votes = _accum_0
    end
    return self:include_in(posts_with_votes, "object_id", {
      flip = true,
      where = {
        object_type = Votes.object_types.post,
        user_id = user_id
      }
    })
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
    opts.ip = opts.ip or self:current_ip_address()
    return _class_0.__parent.create(self, opts)
  end
  self.vote = function(self, object, user, positive)
    if positive == nil then
      positive = true
    end
    local upsert
    upsert = require("community.helpers.models").upsert
    local object_type = self:object_type_for_object(object)
    local old_vote = self:find(user.id, object_type, object.id)
    local counted = object.user_id ~= user.id
    local CommunityUsers
    CommunityUsers = require("community.models").CommunityUsers
    local cu = CommunityUsers:for_user(user)
    local params = {
      object_type = object_type,
      object_id = object.id,
      user_id = user.id,
      positive = not not positive,
      ip = self:current_ip_address(),
      counted = counted,
      score = cu:get_vote_score()
    }
    local action, vote = upsert(self, params)
    if action == "update" and old_vote then
      old_vote:decrement()
    end
    vote:increment()
    return action, vote
  end
  self.unvote = function(self, object, user)
    local object_type = self:object_type_for_object(object)
    local clause = {
      object_type = object_type,
      object_id = object.id,
      user_id = user.id
    }
    local res = unpack(db.query("\n      delete from " .. tostring(db.escape_identifier(self:table_name())) .. "\n      where " .. tostring(db.encode_clause(clause)) .. "\n      returning *\n    "))
    if not (res) then
      return 
    end
    local deleted_vote = self:load(res)
    deleted_vote:decrement()
    return true
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Votes = _class_0
  return _class_0
end
