local db = require("lapis.db")
local enum
enum = require("lapis.db.model").enum
local Model
Model = require("community.model").Model
local PostReports
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "PostReports",
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
  self.statuses = enum({
    pending = 1,
    resolved = 2,
    ignored = 3
  })
  self.reasons = enum({
    other = 1,
    off_topic = 2,
    spam = 3,
    offensive = 4
  })
  self.relations = {
    {
      "category",
      belongs_to = "Categories"
    },
    {
      "post",
      belongs_to = "Posts"
    },
    {
      "user",
      belongs_to = "Users"
    },
    {
      "moderating_user",
      belongs_to = "Users"
    }
  }
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    opts.status = opts.status or "pending"
    opts.status = self.statuses:for_db(opts.status)
    opts.reason = self.reasons:for_db(opts.reason)
    local tname = self:table_name()
    if opts.category_id then
      opts.category_report_number = db.raw(db.interpolate_query("\n        coalesce(\n          (select category_report_number\n            from " .. tostring(db.escape_identifier(tname)) .. " where category_id = ? order by id desc limit 1\n          ), 0) + 1\n      ", opts.category_id))
    end
    assert(opts.post_id, "missing post_id")
    assert(opts.user_id, "missing user_id")
    return Model.create(self, opts)
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  PostReports = _class_0
  return _class_0
end
