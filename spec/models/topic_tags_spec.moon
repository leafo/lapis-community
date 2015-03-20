
import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"
import Users, Categories, Topics, Posts, TopicTags from require "models"

factory = require "spec.factory"

describe "topic tags", ->
  use_test_env!

  local topic

  before_each ->
    truncate_tables Users, Categories, Topics, Posts, TopicTags
    topic = factory.Topics!

  it "should create tag for topic", ->
    tag = TopicTags\create topic_id: topic.id, label: "what up"
    assert.same tag.slug, "what-up"

  it "should set tags", ->
    topic\set_tags "Hello  world  , Yeah"
    tags = TopicTags\select!
    assert.same 2, #tags

    slugs = [tag.slug for tag in *tags]
    table.sort slugs
    assert.same {"hello-world", "yeah"}, slugs

    labels = [tag.label for tag in *tags]
    table.sort labels
    assert.same {"Hello world", "Yeah"}, labels

  it "should set no tags tags", ->
    topic\set_tags ""
    tags = TopicTags\select!
    assert.same 0, #tags

  it "should remove tags", ->
    topic\set_tags "one, two, Three"
    tags = TopicTags\select!
    assert.same 3, #tags

    topic\set_tags "two, yeah"

    tags = TopicTags\select!
    assert.same 2, #tags
