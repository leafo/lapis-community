
-- bulk_increment Things, "views_count", {{id1, 2}, {id2, 2023}}
bulk_increment = (model, column, tuples)->
  db = require "lapis.db"

  table_escaped = db.escape_identifier model\table_name!
  column_escaped = db.escape_identifier column

  buffer = {
    "UPDATE #{table_escaped} "
    "SET #{column_escaped} = #{column_escaped} + increments.amount "
    "FROM (VALUES "
  }

  for t in *tuples
    table.insert buffer, db.escape_literal db.list t
    table.insert buffer, ", "

  buffer[#buffer] = nil

  table.insert buffer, ") AS increments (id, amount) WHERE increments.id = #{table_escaped}.id"
  db.query table.concat buffer

class AsyncCounter
  SLEEP: 0.01
  MAX_TRIES: 10 -- 0.45 seconds to bust
  FLUSH_TIME: 5 -- in seconds

  lock_key: "counter_lock"
  flush_key: "counter_flush"

  increment_immediately: false

  sync_types: {}

  new: (@dict_name, @opts={}) =>
    for k,v in pairs @opts
      @[k] = v

    return unless @dict_name
    return unless ngx

    @dict = assert ngx.shared[@dict_name], "invalid dict name"

  -- runs function when memory is locked, returns retry count
  with_lock: (fn) =>
    i = 0
    while true
      i += 1

      if @dict\add(@lock_key, true, 30) or i == @MAX_TRIES
        success, err = pcall fn
        @dict\delete @lock_key
        assert success, err
        break

      ngx.sleep @SLEEP * i

    if i == @MAX_TRIES
      busted_count_key = "#{@lock_key}_busted"
      @dict\add busted_count_key, 0
      @dict\incr busted_count_key, 1

    i

  increment: (key, amount=1) =>
    if @increment_immediately
      t, id = key\match "(%w+):(%d+)"
      if sync = @sync_types[t]
        sync { {tonumber(id), amount} }

      return true

    return unless @dict

    @with_lock ->
      @dict\add key, 0
      @dict\incr key, amount

      if @dict\add @flush_key, true
        ngx.timer.at @FLUSH_TIME, ->
          @sync!
          import run_after_dispatch from require "lapis.nginx.context"
          run_after_dispatch! -- manually release resources since we are in new context

  sync: =>
    counters_synced = 0

    bulk_updates = {}
    @with_lock ->
      @dict\delete @flush_key
      for key in *@dict\get_keys!
        t, id = key\match "(%w+):(%d+)"
        if t
          counters_synced += 1
          bulk_updates[t] or= {}
          incr = @dict\get key
          table.insert bulk_updates[t], {tonumber(id), incr}
          @dict\delete key

    for t, updates in pairs bulk_updates
      if sync = @sync_types[t]
        sync updates

    counters_synced

{ :AsyncCounter, :bulk_increment }
