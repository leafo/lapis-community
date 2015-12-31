local Model
Model = require("community.model").Model
local concat
concat = table.concat
local TopicTags
do
  local _class_0
  local tag_parser
  local _parent_0 = Model
  local _base_0 = {
    name_for_display = function(self)
      return self.label or self.slug
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "TopicTags",
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
    "topic_id",
    "slug"
  }
  self.timestamp = true
  self.relations = {
    {
      "topic",
      belongs_to = "Topic"
    }
  }
  do
    local lpeg = require("lpeg")
    local R, S, V, P
    R, S, V, P = lpeg.R, lpeg.S, lpeg.V, lpeg.P
    local C, Cs, Ct, Cmt, Cg, Cb, Cc
    C, Cs, Ct, Cmt, Cg, Cb, Cc = lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cmt, lpeg.Cg, lpeg.Cb, lpeg.Cc
    local flatten_words
    flatten_words = function(words)
      return concat(words, " ")
    end
    local sep = P(",")
    local space = S(" \t\r\n")
    local white = space ^ 0
    local word = C((1 - (space + sep)) ^ 1)
    local words = Ct((word * white) ^ 1) / flatten_words
    tag_parser = white * Ct((words ^ -1 * white * sep * white) ^ 0 * words ^ -1 * -1)
  end
  self.parse = function(self, str)
    return tag_parser:match(str) or { }
  end
  self.slugify = function(self, str)
    str = str:gsub("%s+", "-")
    str = str:gsub("[^%w%-_%.]+", "")
    str = str:gsub("^[%-%._]+", "")
    str = str:gsub("[%-%._]+$", "")
    str = str:lower()
    return str
  end
  self.create = function(self, opts)
    if opts == nil then
      opts = { }
    end
    assert(opts.topic_id, "missing topic_id")
    assert(opts.label, "missing label")
    opts.slug = opts.slug or self:slugify(opts.label)
    local safe_insert
    safe_insert = require("community.helpers.models").safe_insert
    return safe_insert(self, opts)
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  TopicTags = _class_0
  return _class_0
end
