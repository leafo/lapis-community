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

{:S, :return_errors, :in_request}
