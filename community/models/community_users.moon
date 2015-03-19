db = require "lapis.db"
import Model from require "community.model"

class CommunityUsers extends Model
  @timestamp: true
  @primary_key: "user_id"

  -- just so it can be users
  @table_name: =>
    import prefix_table from require "community.model"
    name = prefix_table "users"
    @table_name = -> name
    name

  @relations: {
    {"user", belongs_to: "Users"}
  }

