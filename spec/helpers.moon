
assert = require "luassert"
stub = require "luassert.stub"

capture_queries = (fn) ->
  snapshot = assert\snapshot!

  logger = require "lapis.logging"

  query_log = {}
  original = logger.query
  stub(logger, "query").invokes (query, ...) ->
    table.insert query_log, query
    original query, ...

  fn!

  snapshot\revert!

  query_log

assert_queries = (queries, fn) ->
  query_log = capture_queries fn

  msg = if not next queries
    "expected no queries"
  else
    "expected queries to match"

  assert.same queries, query_log, msg

-- this checks if queries are a subset of the actual queries
assert_has_queries = (queries, fn) ->
  query_log = capture_queries fn

  missing_queries = for q in *queries
    found = false
    for logged_q in *query_log
      found = logged_q == q
      break if found

    continue if found
    q

  assert.same {}, missing_queries, "following queries are missing"

assert_no_queries = (fn) ->
  assert_queries {}, fn

-- note: we can't do stub(_G, "pairs") because of a limitation of busted
sorted_pairs = (sort=table.sort) ->
  import before_each, after_each from require "busted"
  local _pairs
  before_each ->
    _pairs = _G.pairs
    _G.pairs = (object, ...) ->
      keys = [k for k in _pairs object]
      sort keys, (a,b) ->
        if type(a) == type(b)
          tostring(a) < tostring(b)
        else
          type(a) < type(b)

      idx = 0

      ->
        idx += 1
        key = keys[idx]
        if key != nil
          key, object[key]

  after_each ->
    _G.pairs = _pairs

{:assert_queries, :assert_has_queries, :assert_no_queries, :sorted_pairs, :capture_queries}
