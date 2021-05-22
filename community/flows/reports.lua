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
local preload
preload = require("lapis.db.model").preload
local filter_update
filter_update = require("community.helpers.models").filter_update
local require_login
require_login = require("community.helpers.app").require_login
local PostReports, Posts, Topics
do
  local _obj_0 = require("community.models")
  PostReports, Posts, Topics = _obj_0.PostReports, _obj_0.Posts, _obj_0.Topics
end
local limits = require("community.limits")
local shapes = require("community.helpers.shapes")
local types
types = require("tableshape").types
local ReportsFlow
do
  local _class_0
  local _parent_0 = Flow
  local _base_0 = {
    expose_assigns = true,
    find_report_for_moderation = function(self)
      local params = shapes.assert_valid(self.params, {
        {
          "report_id",
          shapes.db_id
        }
      })
      local report = assert_error(PostReports:find(self.params.report_id), "invalid report")
      local topic = report:get_post():get_topic()
      assert_error(topic:allowed_to_moderate(self.current_user), "invalid report")
      self.report = report
      return report
    end,
    load_post = function(self)
      local PostsFlow = require("community.flows.posts")
      PostsFlow(self):load_post()
      self.topic = self.post:get_topic()
      assert_error(self.post:allowed_to_report(self.current_user, self._req), "invalid post: not allowed to create report")
      self.report = PostReports:find({
        user_id = self.current_user.id,
        post_id = self.post.id
      })
    end,
    update_or_create_report = require_login(function(self)
      self:load_post()
      local params = shapes.assert_valid(self.params.report, {
        {
          "reason",
          shapes.db_enum(PostReports.reasons)
        },
        {
          "body",
          shapes.empty / db.NULL + shapes.limited_text(limits.MAX_BODY_LEN)
        }
      })
      params = self:copy_post_params(params)
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
    end),
    copy_post_params = function(self, params)
      local out
      do
        local _tbl_0 = { }
        for k, v in pairs(params) do
          _tbl_0[k] = v
        end
        out = _tbl_0
      end
      out.post_user_id = self.post.user_id
      out.post_topic_id = self.post.topic_id
      out.post_body = self.post.body
      out.post_body_format = self.post.body_format
      out.post_parent_post_id = self.post.parent_post_id
      return out
    end,
    show_reports = require_login(function(self, category)
      assert(category, "missing report object")
      assert_error(category:allowed_to_moderate(self.current_user), "invalid category")
      local params = shapes.assert_valid(self.params, {
        {
          "page",
          shapes.page_number
        },
        {
          "status",
          shapes.empty + shapes.db_enum(PostReports.statuses)
        }
      })
      local filter = {
        [db.raw(tostring(db.escape_identifier(PostReports:table_name())) .. ".status")] = params.status
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
      self.reports = self.pager:get_page(params.page)
      return true
    end),
    moderate_report = require_login(function(self)
      local report = self:find_report_for_moderation()
      local action
      action = shapes.assert_valid(self.params, {
        {
          "action",
          shapes.empty / "update" + types.one_of({
            "update",
            "purge"
          })
        }
      }).action
      local _exp_0 = action
      if "purge" == _exp_0 then
        report:delete()
      elseif "update" == _exp_0 then
        local report_update = shapes.assert_valid(self.params.report, {
          {
            "status",
            shapes.db_enum(PostReports.statuses)
          }
        })
        report:update({
          status = report_update.status,
          moderating_user_id = self.current_user.id,
          moderated_at = db.format_date()
        })
        local ModerationLogs
        ModerationLogs = require("community.models").ModerationLogs
        ModerationLogs:create({
          user_id = self.current_user.id,
          object = report,
          category_id = report.category_id,
          action = "report.status(" .. tostring(PostReports.statuses:to_name(report.status)) .. ")"
        })
      end
      return action
    end)
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
