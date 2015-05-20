
class AsyncCounter
  SLEEP: 0.01
  MAX_TRIES: 10 -- 0.45 seconds to bust
  FLUSH_TIME: 10 -- in seconds

  lock_key: "counter_lock"
  flush_key: "counter_flush"

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
      busted_count_key = "#{@lock_key}"
      @dict\add busted_count_key, 0
      @dict\incr busted_count_key, 1

    i

  increment: (key, amount=1) =>
    return unless @dict

    @with_lock ->
      print "incrementing #{key}"
      @dict\add key, 0
      @dict\incr key, amount
      print "INCREMENTED #{key}"

      success, err = @dict\add @flush_key, true
      print "ADDING #{@flush_key}: #{success}"
      if success
        print "setting timer for #{@FLUSH_TIME}"
        ngx.timer.at @FLUSH_TIME, ->
          print "running flush timer"
          @sync!
          import run_after_dispatch from require "lapis.nginx.context"
          run_after_dispatch! -- manually release resources since we are in new context
          print "finished flush timer"
      else
        print "failed to add flush key: #{err}"

  sync: =>
    @with_lock ->
      @dict\delete @flush_key
      for key in *@dict\get_keys!
        t, id = key\match "(%w+):(%d+)"
        if t
          incr = @dict\get key
          print "syncing #{key}"
          if sync = @sync_types[t]
            sync tonumber(id), incr, @

          @dict\delete key

{ :AsyncCounter }
