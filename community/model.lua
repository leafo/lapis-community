local db = require("lapis.db")
local Model
Model = require("lapis.db.model").Model
local OrderedPaginator
OrderedPaginator = require("lapis.db.pagination").OrderedPaginator
local underscore, singularize
do
  local _obj_0 = require("lapis.util")
  underscore, singularize = _obj_0.underscore, _obj_0.singularize
end
local prefix = "community_"
local external_models = {
  Users = true
}
local CommunityModel
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
    __name = "CommunityModel",
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
  self.get_relation_model = function(self, name)
    if external_models[name] then
      return require("models")[name]
    else
      return require("community.models")[name]
    end
  end
  self.table_name = function(self)
    local name = prefix .. underscore(self.__name)
    self.table_name = function()
      return name
    end
    return name
  end
  self.singular_name = function(self)
    local name = singularize(underscore(self.__name))
    self.singular_name = function()
      return name
    end
    return name
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  CommunityModel = _class_0
end
local NestedOrderedPaginator
do
  local _class_0
  local _parent_0 = OrderedPaginator
  local _base_0 = {
    prepare_results = function(self, items)
      items = _class_0.__parent.__base.prepare_results(self, items)
      local parent_field = self.opts.parent_field
      local child_field = self.opts.child_field or "children"
      local by_parent = { }
      local top_level
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #items do
          local _continue_0 = false
          repeat
            local item = items[_index_0]
            do
              local pid = item[parent_field]
              if pid then
                by_parent[pid] = by_parent[pid] or { }
                table.insert(by_parent[pid], item)
              end
            end
            if self.opts.is_top_level_item then
              if not (self.opts.is_top_level_item(item)) then
                _continue_0 = true
                break
              end
            else
              if item[parent_field] then
                _continue_0 = true
                break
              end
            end
            local _value_0 = item
            _accum_0[_len_0] = _value_0
            _len_0 = _len_0 + 1
            _continue_0 = true
          until true
          if not _continue_0 then
            break
          end
        end
        top_level = _accum_0
      end
      for _index_0 = 1, #items do
        local item = items[_index_0]
        item[child_field] = by_parent[item.id]
        do
          local children = self.opts.sort and item[child_field]
          if children then
            self.opts.sort(children)
          end
        end
      end
      return top_level
    end,
    select = function(self, q, opts)
      local tname = db.escape_identifier(self.model:table_name())
      local parent_field = assert(self.opts.parent_field, "missing parent_field")
      local child_field = self.opts.child_field or "children"
      local child_clause = {
        [db.raw("pr." .. tostring(db.escape_identifier(parent_field)))] = db.raw("nested.id")
      }
      do
        local clause = self.opts.child_clause
        if clause then
          for k, v in pairs(clause) do
            child_clause[db.raw("pr." .. tostring(db.escape_identifier(k)))] = v
          end
        end
      end
      local res = db.query("\n      with recursive nested as (\n        (select * from " .. tostring(tname) .. " " .. tostring(q) .. ")\n        union\n        select pr.* from " .. tostring(tname) .. " pr, nested\n          where " .. tostring(db.encode_clause(child_clause)) .. "\n      )\n      select * from nested\n    ")
      for _index_0 = 1, #res do
        local r = res[_index_0]
        self.model:load(r)
      end
      return res
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "NestedOrderedPaginator",
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
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  NestedOrderedPaginator = _class_0
end
local prefix_table
prefix_table = function(table_name)
  return prefix .. table_name
end
return {
  Model = CommunityModel,
  NestedOrderedPaginator = NestedOrderedPaginator,
  prefix_table = prefix_table
}
