

db = require "lapis.db"
import Model from require "lapis.db.model"

prefix = "community_"

class CommunityModel extends Model
  @table_name: =>
    prefix .. Model.table_name @

prefix_table = (table_name) ->
  prefix .. table_name

{ Model: CommunityModel, :prefix_table }
