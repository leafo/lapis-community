import VirtualModel from require "community.model"

-- a user's relationship with another user
class UserUsers extends VirtualModel
  @primary_key: {"source_user_id", "dest_user_id"}

  @relations: {
    {"block_given", has_one: "Blocks", key: {
      blocking_user_id: "source_user_id"
      blocked_user_id: "dest_user_id"
    }}

    {"block_recieved", has_one: "Blocks", key: {
      blocking_user_id: "dest_user_id"
      blocked_user_id: "source_user_id"
    }}
  }
