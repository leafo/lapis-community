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
    increment = function(self)
      local model = self.__class:model_for_object_type(self.object_type)
      local counter_name = self:post_counter_name()
      return db.update(model:table_name(), {
        [counter_name] = db.raw(tostring(db.escape_identifier(counter_name)) .. " + 1")
      }, {
        id = self.object_id
      })
    end,
    decrement = function(self)
      local model = self.__class:model_for_object_type(self.object_type)
      local counter_name = self:post_counter_name()
      return db.update(model:table_name(), {
        [counter_name] = db.raw(tostring(db.escape_identifier(counter_name)) .. " - 1")
      }, {
        id = self.object_id
      })
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
    return Model.create(self, opts)
  end
  self.vote = function(self, object, user, positive)
    if positive == nil then
      positive = true
    end
    local upsert
    upsert = require("community.helpers.models").upsert
    local object_type = self:object_type_for_object(object)
    local old_vote = self:find(user.id, object_type, object.id)
    local params = {
      object_type = object_type,
      object_id = object.id,
      user_id = user.id,
      positive = not not positive
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
