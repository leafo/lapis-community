
assert = require "luassert"
stub = require "luassert.stub"

assert_no_queries = (fn) ->
  snapshot = assert\snapshot!

  logger = require "lapis.logging"

  query_log = {}
  original = logger.query
  stub(logger, "query").invokes (query, ...) ->
    table.insert query_log, query
    original query, ...

  fn!

  snapshot\revert!

  assert.same {}, query_log, "expected no queries"

{:assert_no_queries}
