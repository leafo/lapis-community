factory = require "community.spec.factory"

base_models = require "models"

factory.Users = (opts={}) ->
  community_user = opts.community_user
  opts.community_user = nil
  opts.username or= "user-#{factory.next_counter "username"}"

  with user = assert base_models.Users\create opts
    if community_user
      factory.CommunityUsers user_id: user.id

factory
