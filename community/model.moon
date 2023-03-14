
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

class VirtualModel extends CommunityModel
  @table_name: => error "Attempted to get table name for a VirtualModel: these types of models are not backed by a table and have no table name. Please check your relation definition, and avoid calling methods like find/select/create/update"

  -- this makes the method to load fetch or create the virual model instance
  @make_loader: (name, fn) =>
    (key, ...) =>
      relations = require "lapis.db.model.relations"
      -- TODO: setting a relation's cached value should be an interface in lapis
      @[relations.LOADED_KEY] or={}
      @[relations.LOADED_KEY][name] or= {}
      @[relations.LOADED_KEY][name][key] or= fn @, key, ...
      @[relations.LOADED_KEY][name][key]

  -- only clear the relations, don't try to fetch any data
  refresh: =>
    relations = require "lapis.db.model.relations"

    if loaded_relations = @[relations.LOADED_KEY]
      for name in pairs loaded_relations
        relations.clear_loaded_relation @, name


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

    child_clause = {
      [db.raw "pr.#{db.escape_identifier parent_field}"]: db.raw "nested.id"
    }

    if clause = @opts.child_clause
      for k,v in pairs clause
        field_name = if type(k) == "string"
          db.raw "pr.#{db.escape_identifier k}"
        else
          k

        child_clause[field_name] = v

    base_fields = @opts.base_fields or "*"
    recursive_fields = @opts.recursive_fields or "pr.*"

    res = db.query "
      with recursive nested as (
        (select #{base_fields} from #{tname} #{q})
        union
        select #{recursive_fields} from #{tname} pr, nested
          where #{db.encode_clause child_clause}
      )
      select * from nested
    "

    for r in *res
      @model\load r

    res

prefix_table = (table_name) ->
  prefix .. table_name

{ Model: CommunityModel, :VirtualModel, :NestedOrderedPaginator, :prefix_table }
