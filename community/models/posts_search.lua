local db = require("lapis.db")
local Model
Model = require("community.model").Model
local insert_on_conflict_update
insert_on_conflict_update = require("community.helpers.models").insert_on_conflict_update
local decode_html_entities
do
  local entities = {
    amp = '&',
    nbsp = " ",
    gt = '>',
    lt = '<',
    quot = '"',
    apos = "'",
    mdash = "—",
    rsquo = '’',
    trade = '™',
    ["#x27"] = "'"
  }
  decode_html_entities = function(str)
    return (str:gsub('&(.-);', function(tag)
      if entities[tag] then
        return entities[tag]
      else
        do
          local chr = tag:match("#(%d+)")
          if chr then
            chr = tonumber(chr)
            if chr >= 32 and chr <= 127 then
              return string.char(chr)
            else
              return ""
            end
          else
            return '&' .. tag .. ';'
          end
        end
      end
    end))
  end
end
local PostsSearch
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
    __name = "PostsSearch",
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
  self.primary_key = "post_id"
  self.index_lang = "english"
  self.relations = {
    {
      "post",
      belongs_to = "Posts"
    }
  }
  self.index_post = function(self, post)
    local Extractor
    Extractor = require("web_sanitize.html").Extractor
    local extract_text = Extractor()
    local topic = post:get_topic()
    local body = decode_html_entities(extract_text(post.body))
    local title
    if post:is_topic_post() then
      title = topic.title
    end
    local words
    if title then
      words = db.interpolate_query("setweight(to_tsvector(?, ?), 'A') || setweight(to_tsvector(?, ?), 'B')", self.index_lang, title, self.index_lang, body)
    else
      words = db.interpolate_query("to_tsvector(?, ?)", self.index_lang, body)
    end
    return insert_on_conflict_update(self, {
      post_id = post.id
    }, {
      topic_id = topic.id,
      category_id = topic.category_id,
      words = db.raw(words),
      posted_at = post.created_at
    })
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  PostsSearch = _class_0
  return _class_0
end
