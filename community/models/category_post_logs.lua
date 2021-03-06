local db = require("lapis.db")
local Model
Model = require("community.model").Model
local insert_on_conflict_ignore
insert_on_conflict_ignore = require("community.helpers.models").insert_on_conflict_ignore
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
  self.primary_key = {
    "category_id",
    "post_id"
  }
  self.relations = {
    {
      "post",
      belongs_to = "Posts"
    },
    {
      "category",
      belongs_to = "Categories"
    }
  }
  self.categories_to_log = function(self, category)
    local category_ids
    do
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = category:get_ancestors()
      for _index_0 = 1, #_list_0 do
        local c = _list_0[_index_0]
        if c:should_log_posts() then
          _accum_0[_len_0] = c.id
          _len_0 = _len_0 + 1
        end
      end
      category_ids = _accum_0
    end
    if category:should_log_posts() then
      table.insert(category_ids, category.id)
    end
    return category_ids
  end
  self.log_post = function(self, post)
    local topic = post:get_topic()
    if not (topic) then
      return 
    end
    local category = topic:get_category()
    if not (category) then
      return 
    end
    local category_ids = self:categories_to_log(category)
    if not (next(category_ids)) then
      return 
    end
    local tuples
    do
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #category_ids do
        local id = category_ids[_index_0]
        _accum_0[_len_0] = db.interpolate_query("?", db.list({
          post.id,
          id
        }))
        _len_0 = _len_0 + 1
      end
      tuples = _accum_0
    end
    local tbl = db.escape_identifier(self:table_name())
    return db.query("\n      insert into " .. tostring(tbl) .. " (post_id, category_id)\n      values  " .. tostring(table.concat(tuples, ", ")) .. "\n      on conflict do nothing\n    ", post.id)
  end
  self.log_topic_posts = function(self, topic)
    local category = topic:get_category()
    if not (category) then
      return 
    end
    local category_ids = self:categories_to_log(category)
    if not (next(category_ids)) then
      return 
    end
    local tuples
    do
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #category_ids do
        local id = category_ids[_index_0]
        _accum_0[_len_0] = db.interpolate_query("?", db.list({
          id
        }))
        _len_0 = _len_0 + 1
      end
      tuples = _accum_0
    end
    local Posts
    Posts = require("community.models").Posts
    local tbl = db.escape_identifier(self:table_name())
    return db.query("\n      insert into " .. tostring(tbl) .. " (post_id, category_id)\n      select topic_post_ids.post_id, category_ids.category_id from\n        (select id as post_id from " .. tostring(db.escape_identifier(Posts:table_name())) .. "\n          where topic_id = ? and status = 1 and not deleted) as topic_post_ids(post_id),\n        (values " .. tostring(table.concat(tuples, ", ")) .. ") as category_ids(category_id)\n      on conflict do nothing\n    ", topic.id)
  end
  self.clear_post = function(self, post)
    return db.delete(self:table_name(), {
      post_id = post.id
    })
  end
  self.clear_posts_for_topic = function(self, topic)
    local Posts
    Posts = require("community.models").Posts
    return db.delete(self:table_name(), {
      post_id = db.list({
        db.raw(db.interpolate_query("\n          select id from " .. tostring(db.escape_identifier(Posts:table_name())) .. " where topic_id = ?\n        ", topic.id))
      })
    })
  end
  self.create = insert_on_conflict_ignore
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  CategoryPostLogs = _class_0
  return _class_0
end
