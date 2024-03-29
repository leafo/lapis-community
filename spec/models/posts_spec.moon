db = require "lapis.db"
factory = require "spec.factory"

describe "models.posts", ->
  import Users from require "spec.models"
  import Categories, Topics, Posts, Moderators, CommunityUsers from require "spec.community_models"

  describe "create", ->
    it "creates posts hierarchy", ->
      user = factory.Users!
      topic = factory.Topics!

      make_post = (t={}) ->
        t.user_id = user.id
        t.topic_id = topic.id
        factory.Posts t

      -- it should set post_number and depth correctly based on the use of parent post"
      p1 = make_post!
      p2 = make_post parent_post_id: p1.id
      p3 = make_post parent_post_id: p1.id

      p4 = make_post parent_post_id: p2.id
      p5 = make_post parent_post_id: p2.id

      p6 = make_post parent_post_id: p1.id -- back on original

      p7 = make_post parent_post_id: p3.id

      p8 = factory.Posts! -- some other topic

      res = Posts\select "order by id asc", fields: "id, depth, post_number, parent_post_id"

      assert.same res, {
        {
          id: p1.id
          depth: 1
          post_number: 1
        }
        {
          id: p2.id
          parent_post_id: p1.id
          depth: 2
          post_number: 1
        }
        {
          id: p3.id
          parent_post_id: p1.id
          depth: 2
          post_number: 2
        }
        {
          id: p4.id
          parent_post_id: p2.id
          depth: 3
          post_number: 1
        }
        {
          id: p5.id
          parent_post_id: p2.id
          depth: 3
          post_number: 2
        }
        {
          id: p6.id
          parent_post_id: p1.id
          depth: 2
          post_number: 3
        }
        {
          id: p7.id
          parent_post_id: p3.id
          depth: 3
          post_number: 1
        }
        {
          id: p8.id
          depth: 1
          post_number: 1
        }
      }


  describe "permissions", ->
    local post, post_user, category_user, topic_user, some_user, mod_user, admin_user

    before_each ->
      post_user = factory.Users!
      category_user = factory.Users!
      category = factory.Categories user_id: category_user.id
      topic = factory.Topics category_id: category.id
      post = factory.Posts user_id: post_user.id, topic_id: topic.id
      topic_user = post\get_topic!\get_user!
      some_user = factory.Users!

      category_user = assert topic\get_category!\get_user!, "missing user"
      mod = factory.Moderators object: topic\get_category!
      mod_user = mod\get_user!

      admin_user = with factory.Users!
        .is_admin = => true


    it "checks permissions for default post", ->
      assert.false post\allowed_to_edit nil
      assert.false post\allowed_to_edit topic_user
      assert.false post\allowed_to_edit some_user
      assert.true post\allowed_to_edit post_user
      assert.true post\allowed_to_edit admin_user
      assert.true post\allowed_to_edit category_user
      assert.true post\allowed_to_edit mod_user
      -- otherwise hits topic\allowed_to_moderate

      assert.false post\allowed_to_reply nil
      assert.true post\allowed_to_reply post_user
      assert.true post\allowed_to_reply topic_user
      assert.true post\allowed_to_reply some_user
      assert.true post\allowed_to_reply category_user
      assert.true post\allowed_to_reply mod_user

      assert.false post\allowed_to_report nil
      assert.false post\allowed_to_report post_user
      assert.true post\allowed_to_report topic_user
      assert.true post\allowed_to_report some_user
      assert.true post\allowed_to_report category_user
      assert.true post\allowed_to_report mod_user

    it "checks permissions for archived topic", ->
      -- archived
      post\archive!
      post = Posts\find post.id

      assert.false post\allowed_to_edit nil
      assert.false post\allowed_to_edit topic_user
      assert.false post\allowed_to_edit some_user
      assert.false post\allowed_to_edit post_user
      assert.true post\allowed_to_edit admin_user
      assert.false post\allowed_to_edit category_user
      assert.false post\allowed_to_edit mod_user
      -- otherwise hits topic\allowed_to_moderate

      assert.false post\allowed_to_reply nil
      assert.false post\allowed_to_reply post_user
      assert.false post\allowed_to_reply topic_user
      assert.false post\allowed_to_reply some_user
      assert.false post\allowed_to_reply admin_user
      assert.false post\allowed_to_reply category_user
      assert.false post\allowed_to_reply mod_user

      assert.false post\allowed_to_report nil
      assert.false post\allowed_to_report post_user
      assert.false post\allowed_to_report topic_user
      assert.false post\allowed_to_report some_user
      assert.false post\allowed_to_report admin_user
      assert.false post\allowed_to_report category_user
      assert.false post\allowed_to_report mod_user

    it "checks permissions for protected post", ->
      post\get_topic!\update protected: true
      post = Posts\find post.id

      assert.false post\allowed_to_edit nil
      assert.false post\allowed_to_edit topic_user
      assert.false post\allowed_to_edit some_user
      assert.true post\allowed_to_edit post_user
      assert.true post\allowed_to_edit admin_user
      assert.false post\allowed_to_edit category_user
      assert.false post\allowed_to_edit mod_user
      -- otherwise hits topic\allowed_to_moderate

      assert.false post\allowed_to_reply nil
      assert.true post\allowed_to_reply post_user
      assert.true post\allowed_to_reply topic_user
      assert.true post\allowed_to_reply some_user
      assert.true post\allowed_to_reply category_user
      assert.true post\allowed_to_reply mod_user

      assert.false post\allowed_to_report nil
      assert.false post\allowed_to_report post_user
      assert.true post\allowed_to_report topic_user
      assert.true post\allowed_to_report some_user
      assert.true post\allowed_to_report category_user
      assert.true post\allowed_to_report mod_user

    it "checks permissions for deleted post", ->
      post\update deleted: true

      assert.false post\allowed_to_edit nil
      assert.false post\allowed_to_edit topic_user
      assert.false post\allowed_to_edit some_user
      assert.false post\allowed_to_edit post_user
      assert.false post\allowed_to_edit admin_user
      assert.false post\allowed_to_edit category_user
      assert.false post\allowed_to_edit mod_user

      assert.false post\allowed_to_reply nil
      assert.false post\allowed_to_reply post_user
      assert.false post\allowed_to_reply topic_user
      assert.false post\allowed_to_reply some_user
      assert.false post\allowed_to_reply category_user
      assert.false post\allowed_to_reply mod_user

      assert.false post\allowed_to_report nil
      assert.false post\allowed_to_report post_user
      assert.false post\allowed_to_report topic_user
      assert.false post\allowed_to_report some_user
      assert.false post\allowed_to_report category_user
      assert.false post\allowed_to_report mod_user

      -- this is bizarre, this will let the post render but the post will be
      -- rendered as a "this post is deleted" block. Consider changing this in
      -- the future
      assert.true post\allowed_to_view nil
      assert.true post\allowed_to_view post_user
      assert.true post\allowed_to_view topic_user
      assert.true post\allowed_to_view some_user
      assert.true post\allowed_to_view category_user
      assert.true post\allowed_to_view mod_user

    it "checks permissions for moderation event post", ->
      post\update moderation_log_id: -1

      assert.false post\allowed_to_edit nil
      assert.false post\allowed_to_edit topic_user
      assert.false post\allowed_to_edit some_user
      assert.true post\allowed_to_edit post_user
      assert.true post\allowed_to_edit admin_user
      assert.true post\allowed_to_edit category_user
      assert.true post\allowed_to_edit mod_user

      assert.false post\allowed_to_reply nil
      assert.false post\allowed_to_reply post_user
      assert.false post\allowed_to_reply topic_user
      assert.false post\allowed_to_reply some_user
      assert.false post\allowed_to_reply category_user
      assert.false post\allowed_to_reply mod_user

      assert.false post\allowed_to_report nil
      assert.false post\allowed_to_report post_user
      assert.false post\allowed_to_report topic_user
      assert.false post\allowed_to_report some_user
      assert.false post\allowed_to_report category_user
      assert.false post\allowed_to_report mod_user

      assert.true post\allowed_to_view nil
      assert.true post\allowed_to_view post_user
      assert.true post\allowed_to_view topic_user
      assert.true post\allowed_to_view some_user
      assert.true post\allowed_to_view category_user
      assert.true post\allowed_to_view mod_user


  describe "has_children", ->
    it "with no replies", ->
      post = factory.Posts!
      assert.same false, post\get_has_children!

    it "with replies", ->
      post = factory.Posts!
      factory.Posts topic_id: post.topic_id, parent_post_id: post.id
      assert.same true, post\get_has_children!

    it "with only deleted reply", ->
      post = factory.Posts!
      factory.Posts topic_id: post.topic_id, parent_post_id: post.id, deleted: true
      assert.same true, post\get_has_children!

    it "preloads", ->
      import preload from require "lapis.db.model"

      posts = {
        factory.Posts!
        with p = factory.Posts!
          factory.Posts topic_id: p.topic_id, parent_post_id: p.id

        with p = factory.Posts!
          -- deleted posts also count for having children
          factory.Posts topic_id: p.topic_id, parent_post_id: p.id, deleted: true
      }

      preload posts, "has_children"

      assert.same false, posts[1].has_children
      assert.same true, posts[2].has_children
      assert.same true, posts[3].has_children

  describe "has_next_post", ->
    it "singular post", ->
      post = factory.Posts!
      assert.same false, post\get_has_next_post!

    it "with reply", ->
      post = factory.Posts!
      factory.Posts topic_id: post.topic_id, parent_post_id: post.id
      assert.same false, post\get_has_next_post!

    it "with series", ->
      p1 = factory.Posts!
      p2 = factory.Posts topic_id: p1.topic_id
      assert.same true, p1\get_has_next_post!

    it "with children", ->
      p1 = factory.Posts!
      p1_1 = factory.Posts parent_post_id: p1.id, topic_id: p1.topic_id

      p2 = factory.Posts topic_id: p1.topic_id
      p2_1 = factory.Posts parent_post_id: p2.id, topic_id: p1.topic_id
      p2_2 = factory.Posts parent_post_id: p2.id, topic_id: p1.topic_id

      assert.same true, p2_1\get_has_next_post!
      assert.same false, p2_2\get_has_next_post!
      assert.same false, p1_1\get_has_next_post!

    it "preloads", ->
      import preload from require "lapis.db.model"

      p1 = factory.Posts!
      p1_1 = factory.Posts parent_post_id: p1.id, topic_id: p1.topic_id

      p2 = factory.Posts topic_id: p1.topic_id
      p2_1 = factory.Posts parent_post_id: p2.id, topic_id: p1.topic_id
      p2_2 = factory.Posts parent_post_id: p2.id, topic_id: p1.topic_id

      posts = {
        factory.Posts!
        with p = factory.Posts!
          factory.Posts topic_id: p.topic_id, parent_post_id: p.id

        with p = factory.Posts!
          factory.Posts topic_id: p.topic_id

        p2_1
        p2_2
        p1_1
      }

      preload posts, "has_next_post"

      assert.same false, posts[1].has_next_post
      assert.same false, posts[2].has_next_post
      assert.same true, posts[3].has_next_post

      assert.same true, posts[4].has_next_post
      assert.same false, posts[5].has_next_post
      assert.same false, posts[6].has_next_post


  describe "set status", ->
    it "updates post to spam", ->
      post = factory.Posts!
      post\set_status "spam"

    it "updates topic last post when archiving", ->
      post = factory.Posts!

      topic = post\get_topic!
      topic\increment_from_post post

      topic\refresh!
      assert.same topic.last_post_id, post.id

      post\archive!

      topic\refresh!
      assert.nil topic.last_post_id

  describe "delete", ->
    local topic, post
    before_each ->
      -- permanent so the topic doesn't get deleted with the first poots
      topic = factory.Topics permanent: true
      post = factory.Posts :topic

    assert_topic_counts = (counts) ->
      topic\refresh!

      assert.same counts, {
        root_posts_count: topic.root_posts_count
        posts_count: topic.posts_count
        deleted_posts_count: topic.deleted_posts_count
      }

    it "deletes topic that is the root of non permanent", ->
      topic\update permanent: false
      post\delete!
      topic\refresh!
      assert.true topic.deleted

    it "deletes orphaned posts when hard deleting", ->
      other_post = factory.Posts :topic

      child_1 = factory.Posts :topic, parent_post_id: post.id
      child_2 = factory.Posts :topic, parent_post_id: child_1.id
      post\hard_delete!
      assert.same {[other_post.id]: true}, {post.id, true for post in *Posts\select!}

    it "soft deletes a post", ->
      assert.same 1, topic.root_posts_count
      assert.same 1, topic.posts_count

      cu = CommunityUsers\for_user post\get_user!
      assert.same 0, cu.posts_count

      post\soft_delete!
      post\refresh!
      topic\refresh!

      assert.same true, post.deleted

      assert.same 1, topic.root_posts_count
      assert.same 1, topic.posts_count

      cu\refresh!
      -- we expect this to go to -1 because it was never incremented
      assert.same -1, cu.posts_count

    it "soft deletes then hard deletes", ->
      assert.same 1, topic.root_posts_count, "before root_posts_count"
      assert.same 1, topic.posts_count, "before posts_count"

      cu = CommunityUsers\for_user post\get_user!
      assert.same 0, cu.posts_count

      post\soft_delete!
      topic\refresh!

      assert.same 1, topic.root_posts_count, "root_posts_count after soft"
      assert.same 1, topic.posts_count, "posts_count after soft"
      assert.same 1, topic.deleted_posts_count, "deleted_posts_count after soft"

      post\hard_delete!
      topic\refresh!

      assert.same 0, topic.root_posts_count, "root_posts_count after hard"
      assert.same 0, topic.posts_count, "posts_count after hard"
      assert.same 0, topic.deleted_posts_count, "deleted_posts_count after hard"

      cu\refresh!
      -- we expect this to go to -1 because it was never incremented
      assert.same -1, cu.posts_count

    it "soft deletes then hard deletes moderation event", ->
      topic = factory.Topics permanent: true
      post = factory.Posts :topic, moderation_log_id: -1

      topic\refresh!

      assert.same 1, topic.root_posts_count, "before root_posts_count"
      assert.same 0, topic.posts_count, "before posts_count"

      cu = CommunityUsers\for_user post\get_user!
      assert.same 0, cu.posts_count

      post\soft_delete!
      topic\refresh!

      assert.same 1, topic.root_posts_count, "root_posts_count after soft"
      assert.same 0, topic.posts_count, "posts_count after soft"
      assert.same 0, topic.deleted_posts_count, "deleted_posts_count after soft"

      post\hard_delete!
      topic\refresh!

      assert.same 0, topic.root_posts_count, "root_posts_count after hard"
      assert.same 0, topic.posts_count, "posts_count after hard"
      assert.same 0, topic.deleted_posts_count, "deleted_posts_count after hard"

      cu\refresh!
      assert.same 0, cu.posts_count, "after user posts_count"

    it "hard deletes moderation log", ->
      topic = factory.Topics permanent: true
      post = factory.Posts :topic, moderation_log_id: -1

      topic\refresh!

      assert.same 1, topic.root_posts_count, "before root_posts_count"
      assert.same 0, topic.posts_count, "before posts_count"

      cu = CommunityUsers\for_user post\get_user!
      assert.same 0, cu.posts_count

      post\hard_delete!
      topic\refresh!

      assert.same 0, topic.root_posts_count, "root_posts_count after hard"
      assert.same 0, topic.posts_count, "posts_count after hard"
      assert.same 0, topic.deleted_posts_count, "deleted_posts_count after hard"

      cu\refresh!
      assert.same 0, cu.posts_count, "after user posts_count"

    it "hard deletes a post", ->
      assert.same 1, topic.root_posts_count
      assert.same 1, topic.posts_count

      post\hard_delete!
      topic\refresh!

      assert.same 0, topic.root_posts_count
      assert.same 0, topic.posts_count

    it "hard deletes young post with no replies", ->
      assert_topic_counts {
        posts_count: 1
        root_posts_count: 1
        deleted_posts_count: 0
      }

      post\delete!
      assert.same nil, (Posts\find post.id)

      assert_topic_counts {
        posts_count: 0
        root_posts_count: 0
        deleted_posts_count: 0
      }

    it "soft deletes for posts with next post and parent post", ->
      replies = for i=1,2
        factory.Posts {
          topic_id: post.topic_id
          parent_post: post
        }

      replies[1]\delete!
      replies[1]\refresh!
      assert.same true, replies[1].deleted

    it "soft deletes post with replies", ->
      factory.Posts topic_id: post.topic_id, parent_post_id: post.id
      post\delete!
      post\refresh!
      assert.same true, post.deleted

    it "soft deletes old post", ->
      post\update {
        created_at: db.raw "now() at time zone 'utc' - '1.5 hours'::interval"
      }

      assert_topic_counts {
        posts_count: 1
        root_posts_count: 1
        deleted_posts_count: 0
      }

      post\delete!
      post\refresh!
      assert.same true, post.deleted

      assert_topic_counts {
        posts_count: 1
        root_posts_count: 1
        deleted_posts_count: 1
      }


    it "deletes a moderation log post", ->
      event_post = factory.Posts {
        moderation_log_id: 0
        topic_id: topic.id
      }

      topic\increment_from_post event_post
      topic\refresh!

      assert_topic_counts {
        posts_count: 1
        root_posts_count: 2
        deleted_posts_count: 0
      }

      event_post\delete!
      assert.same 1, Posts\count! -- it hard deleted

      topic\refresh!

      assert_topic_counts {
        posts_count: 1
        root_posts_count: 1
        deleted_posts_count: 0
      }

  it "should create a series of posts in same topic", ->
    posts = for i=1,5
      factory.Posts topic_id: 1

    assert.same [i for i=1,5], [p.post_number for p in *posts]

  it "should create correct post numbers for nested posts", ->
    root1 = factory.Posts topic_id: 1
    assert.same 1, root1.post_number

    root2 = factory.Posts topic_id: 1
    assert.same 2, root2.post_number

    child1 = factory.Posts topic_id: 1, parent_post: root1
    child2 = factory.Posts topic_id: 1, parent_post: root1

    assert.same 1, child1.post_number
    assert.same 2, child2.post_number

    other_child1 = factory.Posts topic_id: 1, parent_post: root2
    other_child2 = factory.Posts topic_id: 1, parent_post: root2

    assert.same 1, other_child1.post_number
    assert.same 2, other_child2.post_number

    root3 = factory.Posts topic_id: 1
    assert.same 3, root3.post_number

    current = root3
    for i=1,3
      current = factory.Posts topic_id: 1, parent_post: current
      assert.same 1, current.post_number


  describe "with post, topic, category", ->
    local post, topic, category

    before_each ->
      category = factory.Categories!
      topic = factory.Topics category_id: category.id
      post = factory.Posts topic_id: topic.id

    it "should check vote status on up down", ->
      category\update voting_type: Categories.voting_types.up_down
      other_user = factory.Users!

      assert.falsy post\allowed_to_vote nil
      assert.truthy post\allowed_to_vote other_user, "up"
      assert.truthy post\allowed_to_vote other_user, "down"

    it "should check vote status on up", ->
      category\update voting_type: Categories.voting_types.up
      other_user = factory.Users!

      assert.falsy post\allowed_to_vote nil
      assert.truthy post\allowed_to_vote other_user, "up"
      assert.falsy post\allowed_to_vote other_user, "down"

    it "should check vote status on disabled", ->
      category\update voting_type: Categories.voting_types.disabled
      other_user = factory.Users!

      assert.falsy post\allowed_to_vote nil
      assert.falsy post\allowed_to_vote other_user, "up"
      assert.falsy post\allowed_to_vote other_user, "down"

  it "should get mentions for post", ->
    factory.Users username: "mentioned_person"
    post = factory.Posts body: "hello @mentioned_person how are you doing @mentioned_person I am @nonexist"
    assert.same {"mentioned_person"}, [u.username for u in *post\get_mentioned_users!]

  it "should preload mentions for many posts", ->
    factory.Users username: "mentioned_person1"
    factory.Users username: "mentioned_person2"

    posts = {
      factory.Posts body: "hello @mentioned_person1 how are you doing @nonexist"
      factory.Posts body: "this is @mentioned_person2 how are you doing"
      factory.Posts body: "this is @mentioned_person2 how are you @mentioned_person1"
      factory.Posts body: "this is @nothing"
    }

    Posts\preload_mentioned_users posts

    usernames = for post in *posts
      [u.username for u in *post.mentioned_users]


    assert.same {"mentioned_person1"}, usernames[1]
    assert.same {"mentioned_person2"}, usernames[2]
    assert.same {"mentioned_person2", "mentioned_person1"}, usernames[3]
    assert.same {}, usernames[4]

  describe "mention targets", ->
    import CategoryGroupCategories, CategoryGroups from require "spec.community_models"

    it "gets no targets for first post", ->
      post = factory.Posts!
      assert.same {}, post\notification_targets!

    it "gets targets for post in topic", ->
      root = factory.Posts!
      topic = root\get_topic!
      topic\increment_from_post root

      post = factory.Posts topic_id: topic.id
      topic\increment_from_post post

      for {kind, user} in *post\notification_targets!
        assert.same "post", kind
        assert.same topic.user_id,user.id

    it "gets targets for post in topic reply", ->
      root = factory.Posts!
      topic = root\get_topic!
      topic\increment_from_post root

      post = factory.Posts parent_post_id: root.id, topic_id: topic.id
      topic\increment_from_post post

      for {kind, user, parent} in *post\notification_targets!
        assert.same "reply", kind
        assert.same topic.user_id, user.id
        assert parent.__class == Posts
        assert.same root.id, parent.id

    it "gets target for category owner", ->
      category_user = factory.Users!
      category = factory.Categories user_id: category_user.id
      topic = factory.Topics category_id: category.id
      post = factory.Posts topic_id: topic.id, user_id: topic.user_id

      tuples = post\notification_targets!
      assert.same 1, #tuples

      tuple = unpack tuples

      assert.same "topic", tuple[1]
      assert.same category_user.id, tuple[2].id
      assert Categories == tuple[3].__class
      assert.same category.id, tuple[3].id

    it "gets target for category group owner owner", ->
      category_group_user = factory.Users!
      group = factory.CategoryGroups user_id: category_group_user.id
      category = factory.Categories!

      group\add_category category

      topic = factory.Topics category_id: category.id
      post = factory.Posts topic_id: topic.id, user_id: topic.user_id

      tuples = post\notification_targets!
      assert.same 1, #tuples

      tuple = unpack tuples

      assert.same "topic", tuple[1]
      assert.same category_group_user.id, tuple[2].id

      assert CategoryGroups == tuple[3].__class
      assert.same group.id, tuple[3].id

  it "gets ancestors of post", ->
    assert.same {}, factory.Posts!\get_ancestors!

  it "gets ancestors of nested post", ->
    parent = factory.Posts!
    post = factory.Posts {
      topic_id: parent.topic_id
      parent_post_id: parent.id
    }

    assert.same {parent.id},
      [p.id for p in *post\get_ancestors!]

  it "gets ancestors of many nested post in deep first", ->
    post = factory.Posts!
    ids = for i=1,5
      with post.id
        post = factory.Posts {
          topic_id: post.topic_id
          parent_post_id: post.id
        }

    ids = [ids[i] for i=#ids,1,-1]

    ancestors = post\get_ancestors!

    assert.same ids, [p.id for p in *ancestors]
    assert.same [i for i=5,1,-1], [p.depth for p in *ancestors]

  it "gets root ancestor", ->
    post = factory.Posts!
    root_post = post
    for i=1,5
      post = factory.Posts {
        topic_id: post.topic_id
        parent_post_id: post.id
      }

    ancestor = post\get_root_ancestor!
    assert.same root_post.id, ancestor.id
    assert.same 1, ancestor.depth

  it "gets vote score", ->
    post = factory.Posts!
    post\refresh!
    assert.same 0, post\vote_score!

    post\update {
      up_votes_count: 3
      down_votes_count: 1
    }

    assert.same 2, post\vote_score!

  describe "pinning", ->
    it "pins post", ->
      topic = factory.Topics!
      posts = for i=1,4
        factory.Posts topic_id: topic.id

      -- move to second slot
      posts[4]\pin_to 2

      assert.same {
        {posts[1].id, 1}
        {posts[4].id, 2}
        {posts[2].id, 3}
        {posts[3].id, 4}
      }, [{p.id, p.post_number} for p in *Posts\select "order by post_number"]

      posts[4]\refresh!
      assert.same 2, posts[4].pin_position

      -- move to top
      posts[2]\pin_to 1

      assert.same {
        {posts[2].id, 1}
        {posts[1].id, 2}
        {posts[4].id, 3}
        {posts[3].id, 4}
      }, [{p.id, p.post_number} for p in *Posts\select "order by post_number"]

      posts[2]\refresh!
      assert.same 1, posts[2].pin_position

      -- repins further down
      posts[2]\pin_to 2

      assert.same {
        {posts[1].id, 1}
        {posts[2].id, 2}
        {posts[4].id, 3}
        {posts[3].id, 4}
      }, [{p.id, p.post_number} for p in *Posts\select "order by post_number"]


  describe "unpin", ->
    local topic, posts

    before_each ->
      topic = factory.Topics!
      posts = for i=1,4
        factory.Posts {
          topic_id: topic.id
          created_at: db.raw db.interpolate_query "
            date_trunc('second', now() at time zone 'utc') + (? || ' days')::interval
          ", i
        }

    it "unpins latest post", ->
      -- move to second slot
      posts[4]\pin_to 2
      posts[4]\refresh!
      posts[4]\unpin!

      assert.same {
        {posts[1].id, 1}
        {posts[2].id, 2}
        {posts[3].id, 3}
        {posts[4].id, 4}
      }, [{p.id, p.post_number} for p in *Posts\select "order by post_number"]

      assert.nil posts[4].pin_position

    it "unpins latest post when real latest is pinned", ->
      -- move to second slot
      posts[4]\pin_to 2
      posts[3]\pin_to 2

      posts[3]\refresh!
      posts[3]\unpin!

      assert.same {
        {posts[1].id, 1}
        {posts[4].id, 2}
        {posts[2].id, 3}
        {posts[3].id, 4}
      }, [{p.id, p.post_number} for p in *Posts\select "order by post_number"]

      assert.nil posts[3].pin_position

    it "unpins post in middle", ->
      -- move to second slot
      posts[3]\pin_to 2
      posts[3]\refresh!
      posts[3]\unpin!

      assert.same {
        {posts[1].id, 1}
        {posts[2].id, 2}
        {posts[3].id, 3}
        {posts[4].id, 4}
      }, [{p.id, p.post_number} for p in *Posts\select "order by post_number"]

      assert.nil posts[3].pin_position


  describe "body_html", ->
    it "gets raw body html", ->
      post = factory.Posts {
        body: "<p>Hello world</p>"
        body_format: "html"
      }

      assert.same "<p>Hello world</p>", post\get_body_html!

    it "gets markdown body as html", ->
      post = factory.Posts {
        body: "**hello world**"
        body_format: "markdown"
      }

      assert.same "<p><strong>hello world</strong></p>\n", post\get_body_html!

  describe "viewing user", ->
    import Blocks, Votes from require "spec.community_models"

    it "fetches models for viewing user", ->
      post = factory.Posts!
      user = factory.Users!

      Blocks\create {
        blocking_user_id: user.id
        blocked_user_id: post.user_id
      }

      Votes\create {
        object_type: Votes.object_types.post
        object_id: post.id
        user_id: user.id
      }

      viewer = post\with_viewing_user(user.id)
      assert.truthy viewer\get_block_given!, "should find block"
      assert.nil viewer\get_block_received!, "no block received"
      assert.truthy viewer\get_vote!, "should find vote"



