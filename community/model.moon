
db = require "lapis.db"
import Model from require "lapis.db.model"

import underscore from require "lapis.util"

prefix = "community_"

singularize = (name)->
  name\match"^(.*)s$" or name

class CommunityModel extends Model
  @table_name: =>
    name = prefix .. underscore @__name
    @table_name = -> name
    name

  @singular_name: =>
    name = singularize underscore @__name
    @singular_name = -> name
    name

prefix_table = (table_name) ->
  prefix .. table_name

{ Model: CommunityModel, :prefix_table }
