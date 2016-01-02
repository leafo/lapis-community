local db = require("lapis.db")
local Model
Model = require("community.model").Model
local safe_insert
safe_insert = require("community.helpers.models").safe_insert
local CategoryPostLogs
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
    __name = "CategoryPostLogs",
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
  self.log_post = function(self, post)
    local topic = post:get_topic()
    if not (topic) then
      return 
    end
    local category = topic:get_category()
    if not (category) then
      return 
    end
    local ids = category:get_category_ids()
    if not (next(ids)) then
      return 
    end
    do
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #ids do
        local id = ids[_index_0]
        _accum_0[_len_0] = db.escape_literal(id)
        _len_0 = _len_0 + 1
      end
      ids = _accum_0
    end
    local tbl = db.escape_identifier(self:table_name())
    return db.query("\n      insert into " .. tostring(tbl) .. " (post_id, category_id)\n      select ?, foo.category_id from \n      (values (" .. tostring(table.concat(ids, "), (")) .. ")) as foo(category_id)\n      where not exists(select 1 from " .. tostring(tbl) .. "\n        where category_id = foo.category_id and post_id = ?)\n    ", post.id, post.id)
  end
  self.clear_post = function(self, post)
    return db.delete(self:table_name(), {
      post_id = post.id
    })
  end
  self.create = safe_insert
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  CategoryPostLogs = _class_0
  return _class_0
end
