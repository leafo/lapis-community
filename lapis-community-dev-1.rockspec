package = "lapis-community"
version = "dev-1"

source = {
  url = "git://github.com/leafo/lapis-community.git"
}

description = {
  summary = "A drop in, full featured community and comment system for Lapis projects",
  license = "MIT",
  maintainer = "Leaf Corcoran <leafot@gmail.com>",
}

dependencies = {
  "lua == 5.1",
  "lapis"
}

build = {
  type = "builtin",
  modules = {
    ["community.flows.bans"] = "community/flows/bans.lua",
    ["community.flows.blocks"] = "community/flows/blocks.lua",
    ["community.flows.bookmarks"] = "community/flows/bookmarks.lua",
    ["community.flows.browsing"] = "community/flows/browsing.lua",
    ["community.flows.categories"] = "community/flows/categories.lua",
    ["community.flows.category_groups"] = "community/flows/category_groups.lua",
    ["community.flows.members"] = "community/flows/members.lua",
    ["community.flows.moderators"] = "community/flows/moderators.lua",
    ["community.flows.posts"] = "community/flows/posts.lua",
    ["community.flows.reports"] = "community/flows/reports.lua",
    ["community.flows.topics"] = "community/flows/topics.lua",
    ["community.flows.votes"] = "community/flows/votes.lua",
    ["community.helpers.app"] = "community/helpers/app.lua",
    ["community.helpers.counters"] = "community/helpers/counters.lua",
    ["community.helpers.html"] = "community/helpers/html.lua",
    ["community.helpers.models"] = "community/helpers/models.lua",
    ["community.limits"] = "community/limits.lua",
    ["community.migrations"] = "community/migrations.lua",
    ["community.model"] = "community/model.lua",
    ["community.models"] = "community/models.lua",
    ["community.models.activity_logs"] = "community/models/activity_logs.lua",
    ["community.models.bans"] = "community/models/bans.lua",
    ["community.models.blocks"] = "community/models/blocks.lua",
    ["community.models.bookmarks"] = "community/models/bookmarks.lua",
    ["community.models.categories"] = "community/models/categories.lua",
    ["community.models.category_group_categories"] = "community/models/category_group_categories.lua",
    ["community.models.category_groups"] = "community/models/category_groups.lua",
    ["community.models.category_members"] = "community/models/category_members.lua",
    ["community.models.community_users"] = "community/models/community_users.lua",
    ["community.models.moderation_log_objects"] = "community/models/moderation_log_objects.lua",
    ["community.models.moderation_logs"] = "community/models/moderation_logs.lua",
    ["community.models.moderators"] = "community/models/moderators.lua",
    ["community.models.pending_posts"] = "community/models/pending_posts.lua",
    ["community.models.post_edits"] = "community/models/post_edits.lua",
    ["community.models.post_reports"] = "community/models/post_reports.lua",
    ["community.models.posts"] = "community/models/posts.lua",
    ["community.models.topic_participants"] = "community/models/topic_participants.lua",
    ["community.models.topic_tags"] = "community/models/topic_tags.lua",
    ["community.models.topics"] = "community/models/topics.lua",
    ["community.models.user_topic_last_seens"] = "community/models/user_topic_last_seens.lua",
    ["community.models.votes"] = "community/models/votes.lua",
    ["community.schema"] = "community/schema.lua",
    ["community.spec.factory"] = "community/spec/factory.lua",
  }
}

