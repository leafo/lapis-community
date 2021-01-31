local bulk_increment
bulk_increment = function(model, column, tuples)
  local db = require("lapis.db")
  local table_escaped = db.escape_identifier(model:table_name())
  local column_escaped = db.escape_identifier(column)
  local buffer = {
    "UPDATE " .. tostring(table_escaped) .. " ",
    "SET " .. tostring(column_escaped) .. " = " .. tostring(column_escaped) .. " + increments.amount ",
    "FROM (VALUES "
  }
  for _index_0 = 1, #tuples do
    local t = tuples[_index_0]
    table.insert(buffer, db.escape_literal(db.list(t)))
    table.insert(buffer, ", ")
  end
  buffer[#buffer] = nil
  table.insert(buffer, ") AS increments (id, amount) WHERE increments.id = " .. tostring(table_escaped) .. ".id")
  return db.query(table.concat(buffer))
end
local AsyncCounter
do
  local _class_0
  local _base_0 = {
    SLEEP = 0.01,
    MAX_TRIES = 10,
    FLUSH_TIME = 5,
    lock_key = "counter_lock",
    flush_key = "counter_flush",
    increment_immediately = false,
    sync_types = { },
    with_lock = function(self, fn)
      local i = 0
      while true do
        i = i + 1
        if self.dict:add(self.lock_key, true, 30) or i == self.MAX_TRIES then
          local success, err = pcall(fn)
          self.dict:delete(self.lock_key)
          assert(success, err)
          break
        end
        ngx.sleep(self.SLEEP * i)
      end
      if i == self.MAX_TRIES then
        local busted_count_key = tostring(self.lock_key) .. "_busted"
        self.dict:add(busted_count_key, 0)
        self.dict:incr(busted_count_key, 1)
      end
      return i
    end,
    increment = function(self, key, amount)
      if amount == nil then
        amount = 1
      end
      if self.increment_immediately then
        local t, id = key:match("(%w+):(%d+)")
        do
          local sync = self.sync_types[t]
          if sync then
            sync({
              {
                tonumber(id),
                amount
              }
            })
          end
        end
        return true
      end
      if not (self.dict) then
        return 
      end
      return self:with_lock(function()
        self.dict:add(key, 0)
        self.dict:incr(key, amount)
        if self.dict:add(self.flush_key, true) then
          return ngx.timer.at(self.FLUSH_TIME, function()
            self:sync()
            local run_after_dispatch
            run_after_dispatch = require("lapis.nginx.context").run_after_dispatch
            return run_after_dispatch()
          end)
        end
      end)
    end,
    sync = function(self)
      local bulk_updates = { }
      self:with_lock(function()
        self.dict:delete(self.flush_key)
        local _list_0 = self.dict:get_keys()
        for _index_0 = 1, #_list_0 do
          local key = _list_0[_index_0]
          local t, id = key:match("(%w+):(%d+)")
          if t then
            local _update_0 = t
            bulk_updates[_update_0] = bulk_updates[_update_0] or { }
            local incr = self.dict:get(key)
            table.insert(bulk_updates[t], {
              tonumber(id),
              incr
            })
            self.dict:delete(key)
          end
        end
      end)
      for t, updates in pairs(bulk_updates) do
        do
          local sync = self.sync_types[t]
          if sync then
            sync(updates)
          end
        end
      end
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, dict_name, opts)
      if opts == nil then
        opts = { }
      end
      self.dict_name, self.opts = dict_name, opts
      for k, v in pairs(self.opts) do
        self[k] = v
      end
      if not (self.dict_name) then
        return 
      end
      if not (ngx) then
        return 
      end
      self.dict = assert(ngx.shared[self.dict_name], "invalid dict name")
    end,
    __base = _base_0,
    __name = "AsyncCounter"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  AsyncCounter = _class_0
end
return {
  AsyncCounter = AsyncCounter,
  bulk_increment = bulk_increment
}
