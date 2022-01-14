import Users from require "models"
import Topics from require "community.models"

factory = require "spec.factory"

describe "community.helpers.counters", ->
  import Users from require "spec.models"
  import Topics from require "spec.community_models"

  it "should bulk increment", ->
    t1 = factory.Topics!
    t2 = factory.Topics!
    t3 = factory.Topics!

    import bulk_increment from require "community.helpers.counters"

    bulk_increment Topics, "views_count", {
      {t1.id, 1}, {t2.id, 2}
    }

    t1\refresh!
    t2\refresh!
    t3\refresh!

    assert.same 1, t1.views_count
    assert.same 2, t2.views_count
    assert.same 0, t3.views_count



