import Application from require "lapis.application"
import capture_errors from require "lapis.application"
import mock_action from require "lapis.spec.request"

return_errors = (fn) ->
  capture_errors fn, (req) ->
    nil, req.errors

assert = require "luassert"

class S extends Application
  flows_prefix: "community.flows"

  -- run the / action directly with no routing or error capturing
  dispatch: (req, res) =>
    r = @.Request @, req, res
    @wrap_handler(@["/"]) {}, req.parsed_url.path, "index", r
    @render_request r

in_request = (opts, run) ->
  assert mock_action S, "/", opts, return_errors run

-- this creates a proxy object for calling flow methods in the context of a request:
-- flow("categories", user: current_user, post: { category_id: 10 })\recent_posts {}
flow = (flow_name, opts={}) ->
  setmetatable { }, {
    __index: (proxy, field) ->
      flow_cls = require "community.flows.#{flow_name}"

      v = flow_cls.__base[field]

      switch type(v)
        when "function"
          (_, ...) ->
            args = {...}

            in_request {
              post: opts.post
              get: opts.get
            }, =>
              proxy._last_request = @
              @current_user = opts.user

              if opts.init
                if type(opts.init) == "function"
                  opts.init @
                else
                  for k,v in pairs opts.init
                    @[k] = v

              f = flow_cls @
              f[field] f, unpack args
        else
          v
  }


{:S, :return_errors, :in_request, :flow}
