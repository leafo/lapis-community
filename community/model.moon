
db = require "lapis.db"
import Model from require "lapis.db.model"
import OrderedPaginator from require "lapis.db.pagination"

import underscore, singularize from require "lapis.util"

prefix = "community_"

external_models = {
  Users: true
}

class CommunityModel extends Model
  @get_relation_model: (name) =>
    if external_models[name]
      require("models")[name]
    else
      require("community.models")[name]

  @table_name: =>
    name = prefix .. underscore @__name
    @table_name = -> name
    name

  @singular_name: =>
    name = singularize underscore @__name
    @singular_name = -> name
    name

class NestedOrderedPaginator extends OrderedPaginator
  prepare_results: (items) =>
    items = super items

    parent_field = @opts.parent_field
    child_field = @opts.child_field or "children"

    by_parent = {}

    -- sort and nest
    top_level = for item in *items
      if pid = item[parent_field]
        by_parent[pid] or= {}
        table.insert by_parent[pid], item

      if @opts.is_top_level_item
        continue unless @opts.is_top_level_item item
      else
        continue if item[parent_field]

      item

    for item in *items
      item[child_field] = by_parent[item.id]
      if children = @opts.sort and item[child_field]
        @opts.sort children

    top_level

  select: (q, opts) =>
    tname = db.escape_identifier @model\table_name!
    parent_field = assert @opts.parent_field, "missing parent_field"
    child_field = @opts.child_field or "children"

    res = db.query "
      with recursive nested as (
        (select * from #{tname} #{q})
        union
        select pr.* from #{tname} pr, nested
          where pr.#{db.escape_identifier parent_field} = nested.id
      )
      select * from nested
    "

    for r in *res
      @model\load r

    res

prefix_table = (table_name) ->
  prefix .. table_name

{ Model: CommunityModel, :NestedOrderedPaginator, :prefix_table }
