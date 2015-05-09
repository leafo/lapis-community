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
		["community.flows.browsing"] = "community/flows/browsing.lua",
		["community.flows.categories"] = "community/flows/categories.lua",
		["community.flows.members"] = "community/flows/members.lua",
		["community.flows.moderators"] = "community/flows/moderators.lua",
		["community.flows.posts"] = "community/flows/posts.lua",
		["community.flows.reports"] = "community/flows/reports.lua",
		["community.flows.topics"] = "community/flows/topics.lua",
		["community.helpers.app"] = "community/helpers/app.lua",
		["community.helpers.models"] = "community/helpers/models.lua",
		["community.limits"] = "community/limits.lua",
		["community.migrations"] = "community/migrations.lua",
		["community.model"] = "community/model.lua",
		["community.models"] = "community/models.lua",
		["community.models.bans"] = "community/models/bans.lua",
		["community.models.blocks"] = "community/models/blocks.lua",
		["community.models.categories"] = "community/models/categories.lua",
		["community.models.category_members"] = "community/models/category_members.lua",
		["community.models.category_moderators"] = "community/models/category_moderators.lua",
		["community.models.community_users"] = "community/models/community_users.lua",
		["community.models.post_edits"] = "community/models/post_edits.lua",
		["community.models.post_replies"] = "community/models/post_replies.lua",
		["community.models.post_reports"] = "community/models/post_reports.lua",
		["community.models.post_votes"] = "community/models/post_votes.lua",
		["community.models.posts"] = "community/models/posts.lua",
		["community.models.topic_participants"] = "community/models/topic_participants.lua",
		["community.models.topic_tags"] = "community/models/topic_tags.lua",
		["community.models.topics"] = "community/models/topics.lua",
		["community.schema"] = "community/schema.lua",
  }
}
