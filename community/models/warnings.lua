local db = require("lapis.db")
local enum
enum = require("lapis.db.model").enum
local Model
Model = require("community.model").Model
local db_json
db_json = require("community.helpers.models").db_json
local Warnings
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = {
    is_active = function(self)
      local date = require("date")
      return not self.expires_at or date(true) < date(self.expires_at)
    end,
    has_started = function(self)
      return self.first_seen_at ~= nil
    end,
    start_warning = function(self)
      return self:update({
        first_seen_at = db.raw("date_trunc('second', now() at time zone 'UTC')"),
        expires_at = db.raw([[date_trunc('second', now() at time zone 'UTC') + duration]])
      }, {
        where = db.clause({
          first_seen_at = db.NULL
        })
      })
    end,
    end_warning = function(self)
      return self:update({
        first_seen_at = db.raw("coalesce(first_seen_at, date_trunc('second', now() at time zone 'UTC'))"),
        expires_at = db.raw([[date_trunc('second', now() at time zone 'UTC')]])
      }, {
        where = db.clause({
          "expires_at IS NULL or now() at time zone 'utc' < expires_at"
        })
      })
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "Warnings",
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
  self.relations = {
    {
      "user",
      belongs_to = "Users"
    },
    {
      "moderating_user",
      belongs_to = "Users"
    },
    {
      "post",
      belongs_to = "Posts"
    },
    {
      "post_report",
      belongs_to = "PostReports"
    }
  }
  self.restrictions = enum({
    notify = 1,
    block_posting = 2,
    pending_posting = 3
  })
  self.create = function(self, opts, ...)
    if opts.restriction then
      opts.restriction = self.restrictions:for_db(opts.restriction)
    end
    if opts.data then
      opts.data = db_json(opts.data)
    end
    return _class_0.__parent.create(self, opts, ...)
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Warnings = _class_0
  return _class_0
end
