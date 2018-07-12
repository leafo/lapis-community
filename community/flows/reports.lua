local Flow
Flow = require("lapis.flow").Flow
local db = require("lapis.db")
local assert_error, yield_error
do
  local _obj_0 = require("lapis.application")
  assert_error, yield_error = _obj_0.assert_error, _obj_0.yield_error
end
local assert_valid
assert_valid = require("lapis.validate").assert_valid
local filter_update
filter_update = require("community.helpers.models").filter_update
local trim_filter
trim_filter = require("lapis.util").trim_filter
local assert_page, require_login
do
  local _obj_0 = require("community.helpers.app")
  assert_page, require_login = _obj_0.assert_page, _obj_0.require_login
end
local preload
preload = require("lapis.db.model").preload
local PostReports, Posts, Topics
do
  local _obj_0 = require("community.models")
  PostReports, Posts, Topics = _obj_0.PostReports, _obj_0.Posts, _obj_0.Topics
end
local limits = require("community.limits")
local ReportsFlow
do
  local _class_0
  local _parent_0 = Flow
  local _base_0 = {
    expose_assigns = true,
    load_post = function(self)
      assert_valid(self.params, {
        {
          "post_id",
          is_integer = true
        }
      })
      local PostsFlow = require("community.flows.posts")
      PostsFlow(self):load_post()
      self.topic = self.post:get_topic()
      assert_error(self.post:allowed_to_report(self.current_user, self._req), "invalid post")
      self.report = PostReports:find({
        user_id = self.current_user.id,
        post_id = self.post.id
      })
    end,
    validate_params = function(self)
      self:load_post()
      assert_valid(self.params, {
        {
          "report",
          type = "table"
        }
      })
      local params = trim_filter(self.params.report, {
        "reason",
        "body"
      })
      assert_valid(params, {
        {
          "reason",
          one_of = PostReports.reasons
        },
        {
          "body",
          optional = true,
          max_length = limits.MAX_BODY_LEN
        }
      })
      params.reason = PostReports.reasons:for_db(params.reason)
      return params
    end,
    update_or_create_report = function(self)
      self:load_post()
      local params = self:validate_params()
      if self.report then
        self.report:update(filter_update(self.report, params))
        return "update"
      else
        params.user_id = self.current_user.id
        params.post_id = self.post.id
        params.category_id = self.topic.category_id
        self.report = PostReports:create(params)
        return "create"
      end
    end,
    show_reports = function(self, category)
      assert(category, "missing report object")
      assert_error(category:allowed_to_moderate(self.current_user), "invalid category")
      assert_page(self)
      assert_valid(self.params, {
        {
          "status",
          one_of = PostReports.statuses,
          optional = true
        }
      })
      local filter = {
        [db.raw(tostring(db.escape_identifier(PostReports:table_name())) .. ".status")] = self.params.status and PostReports.statuses:for_db(self.params.status)
      }
      local children = self.category:get_flat_children()
      local category_ids
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #children do
          local c = children[_index_0]
          _accum_0[_len_0] = c.id
          _len_0 = _len_0 + 1
        end
        category_ids = _accum_0
      end
      table.insert(category_ids, self.category.id)
      self.pager = PostReports:paginated("\n      inner join " .. tostring(db.escape_identifier(Posts:table_name())) .. " as posts\n        on posts.id = post_id\n\n      inner join " .. tostring(db.escape_identifier(Topics:table_name())) .. " as topics\n        on posts.topic_id = topics.id\n\n      where " .. tostring(db.escape_identifier(PostReports:table_name())) .. ".category_id in ? and not posts.deleted and not topics.deleted\n\n      " .. tostring(next(filter) and "and " .. db.encode_clause(filter) or "") .. "\n      order by id desc\n    ", db.list(category_ids), {
        fields = tostring(db.escape_identifier(PostReports:table_name())) .. ".*",
        prepare_results = function(reports)
          preload(reports, "category", "user", "moderating_user", {
            post = "topic"
          })
          return reports
        end
      })
      self.reports = self.pager:get_page()
      return true
    end,
    moderate_report = function(self)
      assert_valid(self.params, {
        {
          "report_id",
          is_integer = true
        },
        {
          "report",
          type = "table"
        }
      })
      self.report = assert_error(PostReports:find(self.params.report_id))
      local topic = self.report:get_post():get_topic()
      assert_error(topic:allowed_to_moderate(self.current_user), "invalid report")
      local report = trim_filter(self.params.report)
      assert_valid(report, {
        {
          "status",
          one_of = PostReports.statuses
        }
      })
      self.report:update({
        status = PostReports.statuses:for_db(report.status),
        moderating_user_id = self.current_user.id,
        moderated_at = db.format_date()
      })
      local ModerationLogs
      ModerationLogs = require("community.models").ModerationLogs
      ModerationLogs:create({
        user_id = self.current_user.id,
        object = self.report,
        category_id = self.report.category_id,
        action = "report.status(" .. tostring(report.status) .. ")"
      })
      return true
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, req)
      _class_0.__parent.__init(self, req)
      return assert(self.current_user, "missing current user for reports flow")
    end,
    __base = _base_0,
    __name = "ReportsFlow",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  ReportsFlow = _class_0
  return _class_0
end
