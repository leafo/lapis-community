config = require "lapis.config"

config "development", ->
  postgres {
    backend: "pgmoon"
    database: "community"
  }

config "test", ->
  postgres {
    backend: "pgmoon"
    database: "community_test"
  }


