config = require "lapis.config"

config "development", ->
  measure_performance true

  postgres {
    backend: "pgmoon"
    database: "community"
  }

  community {
    view_counter_dict: "view_counters"
  }

config "test", ->
  measure_performance true
  logging {
    requests: true
    queries: false
    server: true
  }

  postgres {
    backend: "pgmoon"
    database: "community_test"

    host: os.getenv "PGHOST"
    user: os.getenv "PGUSER"
    password: os.getenv "PGPASSWORD"
  }


