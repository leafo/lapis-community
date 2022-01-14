db = require "lapis.db"
factory = require "spec.factory"

describe "models.posts", ->
  import Users from require "spec.models"
  import Categories, Topics, Posts, PostsSearch from require "spec.community_models"

  local snapshot

  before_each ->
    snapshot = assert\snapshot!
    current_user = factory.Users!

  after_each ->
    snapshot\revert!

  it "indexes a post", ->
    post = factory.Posts body: "Hello how are you"
    topic = post\get_topic!
    topic\update title: "This Is My Topic"
    post.should_index_for_search = -> true

    -- insert initial
    search = assert post\refresh_search_index!
    assert.same post.id, search.post_id
    assert.same topic.id, search.topic_id
    assert.same topic\get_category!.id, search.category_id
    assert.same post.created_at, search.posted_at

    post\refresh!
    -- update it 
    post.should_index_for_search = -> true
    post\update body: "another topic with another description"
    assert post\refresh_search_index!

  it "removes post that no longer needs to be indexed", ->
    post = factory.Posts!
    assert PostsSearch\index_post post

    post.should_index_for_search = -> false
    post\refresh_search_index!

    assert.same 0, PostsSearch\count!



