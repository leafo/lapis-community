config = require "lapis.config"

config "development", ->
  postgres {
    backend: "pgmoon"
    database: "community"
  }

  community {
    view_counter_dict: "view_counters"
  }

config "test", ->
  postgres {
    backend: "pgmoon"
    database: "community_test"
  }


