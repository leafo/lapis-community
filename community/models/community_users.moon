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

  @create: (opts={}) =>
    assert opts.user_id, "missing user id"
    Model.create @, opts

  @for_user: (user_id) =>
    user_id = user_id.id if type(user_id) == "table"
    community_user = @find(:user_id)


