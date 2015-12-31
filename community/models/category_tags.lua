local Model
Model = require("community.model").Model
local CategoryTags
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
    __name = "CategoryTags",
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
      "category",
      belongs_to = "Categories"
    }
  }
  self.slugify = function(self, str)
    str = str:gsub("%s+", "-")
    str = str:gsub("[^%w%-_%.]+", "")
    str = str:gsub("^[%-%._]+", "")
    str = str:gsub("[%-%._]+$", "")
    if str == "" then
      return nil
    end
    str = str:lower()
    return str
  end
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    if opts.label and not opts.slug then
      opts.slug = self:slugify(opts.label)
      if not (opts.slug) then
        return nil, "invalid label"
      end
    end
    if opts.slug == opts.label then
      opts.label = nil
    end
    return _class_0.__parent.create(self, opts)
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  CategoryTags = _class_0
  return _class_0
end
