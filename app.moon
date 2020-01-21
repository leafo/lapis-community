lapis = require "lapis"

import respond_to, capture_errors, capture_errors_json,
  assert_error from require "lapis.application"

import preload from require "lapis.db.model"

import assert_valid from require "lapis.validate"

class extends lapis.Application
  layout: require "views.layout"

  @before_filter =>
    if id = @session.user_id
      import Users from require "models"
      @current_user = Users\find(:id)

  [register: "/register"]: respond_to {
    GET: =>
      render: true

    POST: capture_errors =>
      import Users from require "models"

      assert_valid @params, {
        {"username", exists: true}
      }

      user = Users\create {
        username: @params.username
      }

      @session.user_id = user.id
      redirect_to: @url_for "index"
  }

  [login: "/login"]: respond_to {
    GET: =>
      render: true

    POST: capture_errors =>
      import Users from require "models"
      assert_valid @params, {
        {"username", exists: true}
      }

      user = assert_error Users\find(username: @params.username), "invalid user"
      @session.user_id = user.id

      redirect_to: @url_for "index"
  }

  [new_category: "/new-category"]: respond_to {
    GET: => render: true

    POST: capture_errors =>
      CategoriesFlow = require "community.flows.categories"
      CategoriesFlow(@)\new_category!

      redirect_to: @url_for "index"
  }

  [edit_category: "/category/:category_id/edit"]: capture_errors_json respond_to {
    before: =>
      CategoriesFlow = require "community.flows.categories"
      @flow = CategoriesFlow @
      @flow\load_category!
      assert_error @category\allowed_to_edit(@current_user), "invalid user"
      @editing = true

    GET: =>
      render: true

    POST: capture_errors =>
      @flow\edit_category @
      redirect_to: @url_for "category", category_id: @category.id
  }

  [new_topic: "/category/:category_id/new-topic"]: capture_errors_json respond_to {
    before: =>
      CategoriesFlow = require "community.flows.categories"
      CategoriesFlow(@)\load_category!
      assert_error @category\allowed_to_post_topic(@current_user, @), "not allowed to post"

    GET: =>
      render: true

    POST: capture_errors =>
      TopicsFlow = require "community.flows.topics"
      TopicsFlow(@)\new_topic!
      redirect_to: @url_for "category", category_id: @category.id
  }

  [new_post: "/topic/:topic_id/new-post"]: capture_errors_json respond_to {
    before: =>
      TopicsFlow = require "community.flows.topics"
      TopicsFlow(@)\load_topic!
      assert_error @topic\allowed_to_post(@current_user, @), "not allowed to post"

    GET: =>
      render: true

    POST: capture_errors =>
      PostsFlow = require "community.flows.posts"
      PostsFlow(@)\new_post!
      redirect_to: @url_for "topic", topic_id: @topic.id
  }

  [edit_post: "/post/:post_id/edit"]: capture_errors_json respond_to {
    before: =>
      @editing = true

      PostsFlow = require "community.flows.posts"
      @flow = PostsFlow @
      @flow\load_post!

      @topic = @post\get_topic!

      assert_error @post\allowed_to_edit(@current_user), "invalid post"

    GET: =>
      render: true

    POST: =>
      @flow\edit_post!
      redirect_to: @url_for "topic", topic_id: @topic.id
  }

  [delete_post: "/post/:post_id/delete"]: capture_errors_json respond_to {
    before: =>
      PostsFlow = require "community.flows.posts"
      @flow = PostsFlow @
      @flow\load_post!
      @topic = @post\get_topic!

      assert_error @post\allowed_to_edit(@current_user), "invalid post"

    GET: =>
      render: true

    POST: =>
      @flow\delete_post!
      if @post\is_topic_post!
        if @category = @topic\get_category!
          { redirect_to: @url_for "category", category_id: @category.id }
        else
          { redirect_to: @url_for "index" }
      else
        { redirect_to: @url_for "topic", topic_id: @topic.id }
  }

  [vote_object: "/vote/:object_type/:object_id"]: capture_errors_json respond_to {
    POST: =>
      VotesFlow = require "community.flows.votes"
      flow = VotesFlow @
      flow\vote!

      switch @params.object_type
        when "post"
          topic = @object\get_topic!
          redirect_to: @url_for "topic", topic_id: topic.id
        else
          error "got no where to go"
  }

  [reply_post: "/post/:post_id/reply"]: respond_to {
    before: =>
      PostsFlow = require "community.flows.posts"
      @flow = PostsFlow @
      @flow\load_post!
      @topic = @post\get_topic!

      @parent_post = @post
      @post = nil

      assert_error @parent_post\allowed_to_reply(@user), "invalid post"

    GET: =>
      render: true

    POST: =>
      @flow\new_post!
      redirect_to: @url_for "topic", topic_id: @topic.id
  }

  [category: "/category/:category_id"]: capture_errors_json =>
    BrowsingFlow = require "community.flows.browsing"
    @flow = BrowsingFlow(@)

    @flow\category_topics!
    @flow\sticky_category_topics!

    @user = @category\get_user!
    render: true

  [topic: "/topic/:topic_id"]: capture_errors_json =>
    BrowsingFlow = require "community.flows.browsing"
    BrowsingFlow(@)\topic_posts {
      order: @params.order
    }
    render: true

  [post: "/post/:post_id"]: capture_errors_json =>
    BrowsingFlow = require "community.flows.browsing"
    BrowsingFlow(@)\post_single!
    render: true

  [user: "/user/:user_id"]: capture_errors_json =>
    import Users from require "models"
    import CommunityUsers from require "community.models"
    assert_valid @params, {
      {"user_id", is_integer: true}
    }

    @user = Users\find @params.user_id
    @community_user = CommunityUsers\for_user @user
    render: true

  [category_members: "/category/:category_id/members"]: capture_errors_json =>
    CategoriesFlow = require "community.flows.categories"
    @flow = CategoriesFlow @
    @flow\load_category!
    assert_error @category\allowed_to_edit_members(@current_user), "invalid category"
    @flow\members_flow!\show_members!
    render: true

  [category_new_member: "/category/:category_id/new-member"]: capture_errors_json respond_to {
    before: =>
      CategoriesFlow = require "community.flows.categories"
      @flow = CategoriesFlow @
      @flow\load_category!
      assert_error @category\allowed_to_edit_members(@current_user), "invalid category"

    GET: =>
      render: true

    POST: capture_errors =>
      @flow\members_flow!\add_member!
      redirect_to: @url_for "category_members", category_id: @category.id
  }

  [category_remove_member: "/category/:category_id/remove-member/:user_id"]: capture_errors_json respond_to {
    POST: =>
      CategoriesFlow = require "community.flows.categories"
      @flow = CategoriesFlow(@)
      @flow\load_category!
      @flow\members_flow!\remove_member!
      redirect_to: @url_for "category_members", category_id: @category.id
  }

  [category_accept_member: "/category/:category_id/accept-member"]: capture_errors_json respond_to {
    before: =>
      CategoriesFlow = require "community.flows.categories"
      @flow = CategoriesFlow @
      @flow\load_category!

      @member = @category\find_member @current_user
      assert_error @member and not @member.accepted, "invalid member"

    GET: =>
      render: true

    POST: =>
      @flow\members_flow!\accept_member!
      redirect_to: @url_for "category", category_id: @category.id
  }

  [category_moderators: "/category/:category_id/moderators"]: capture_errors_json =>
    CategoriesFlow = require "community.flows.categories"
    @flow = CategoriesFlow @
    @flow\load_category!

    assert_error @category\allowed_to_moderate(@current_user), "invalid category"

    @flow\moderators_flow!\show_moderators!
    render: true

  [category_new_moderator: "/category/:category_id/new-moderator"]: capture_errors respond_to {
    before: =>
      CategoriesFlow = require "community.flows.categories"
      @flow = CategoriesFlow(@)
      @flow\load_category!

      assert_error @category\allowed_to_edit_moderators(@current_user),
        "invalid category"


    GET: =>
      render: true

    POST: =>
      @flow\moderators_flow!\add_moderator!
      redirect_to: @url_for "category_moderators", category_id: @category.id
  }

  [category_remove_moderator: "/category/:category_id/remove-moderator/:user_id"]: capture_errors_json respond_to {
    before: =>
      CategoriesFlow = require "community.flows.categories"
      @flow = CategoriesFlow(@)
      @flow\load_category!

    POST: =>
      @flow\moderators_flow!\remove_moderator!

      if @category\allowed_to_moderate @current_user
        { redirect_to: @url_for "category_moderators", category_id: @category.id }
      else
        { redirect_to: @url_for "category", category_id: @category.id }
  }

  [category_accept_moderator: "/category/:category_id/accept-moderator"]: capture_errors_json respond_to {
    before: =>
      CategoriesFlow = require "community.flows.categories"
      @flow = CategoriesFlow(@)
      @flow\load_category!
      @moderator = @category\find_moderator @current_user
      assert_error @moderator and not @moderator.accepted, "invalid moderator"

    GET: =>
      render: true

    POST: =>
      @flow\moderators_flow!\accept_moderator_position!
      redirect_to: @url_for "category_moderators", category_id: @category.id
  }

  [lock_topic: "/topic/:topic_id/lock"]: capture_errors_json respond_to {
    before: =>
      TopicsFlow = require "community.flows.topics"
      @flow = TopicsFlow @
      @flow\load_topic_for_moderation!

    GET: =>
      render: true

    POST: =>
      @flow\lock_topic!
      redirect_to: @url_for "topic", topic_id: @topic.id
  }

  [unlock_topic: "/topic/:topic_id/unlock"]: capture_errors_json respond_to {
    POST: =>
      TopicsFlow = require "community.flows.topics"
      TopicsFlow(@)\unlock_topic!
      redirect_to: @url_for "topic", topic_id: @topic.id
  }

  [stick_topic: "/topic/:topic_id/stick"]: capture_errors_json respond_to {
    before: =>
      TopicsFlow = require "community.flows.topics"
      @flow = TopicsFlow @
      @flow\load_topic_for_moderation!

    GET: =>
      render: true

    POST: =>
      @flow\stick_topic!
      redirect_to: @url_for "topic", topic_id: @topic.id
  }

  [unstick_topic: "/topic/:topic_id/unstick"]: capture_errors_json respond_to {
    POST: =>
      TopicsFlow = require "community.flows.topics"
      TopicsFlow(@)\unstick_topic!
      redirect_to: @url_for "topic", topic_id: @topic.id

  }

  [block_user: "/block/:blocked_user_id"]: capture_errors_json respond_to {
    POST: =>
      BlocksFlow = require "community.flows.blocks"
      json: { success: BlocksFlow(@)\block_user! }
  }

  [unblock_user: "/unblock/:blocked_user_id"]: capture_errors_json respond_to {
    POST: =>
      BlocksFlow = require "community.flows.blocks"
      json: { success: BlocksFlow(@)\unblock_user! }
  }

  [index: "/"]: =>
    import Users from require "models"
    import Categories from require "community.models"

    @categories = Categories\select!
    preload @categories, "user", "last_topic"

    render: true

