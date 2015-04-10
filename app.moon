lapis = require "lapis"

import respond_to, capture_errors, capture_errors_json,
  assert_error from require "lapis.application"

import assert_valid from require "lapis.validate"

class extends lapis.Application
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

  [new_topic: "/category/:category_id/new-topic"]: capture_errors respond_to {
    before_filter: =>
      CategoriesFlow = require "community.flows.categories"
      CategoriesFlow(@)\load_category!

    GET:  =>
      render: true

    POST:  =>
      TopicsFlow = require "community.flows.topics"
      TopicsFlow(@)\new_topic!
      redirect_to: @url_for "category", category_id: @category.id
  }

  [new_post: "/topic/:topic_id/new-post"]: capture_errors respond_to {
    GET: =>
      render: true

    POST: =>
      PostsFlow = require "community.flows.posts"
      PostsFlow(@)\new_post!
      redirect_to: @url_for "topic", topic_id: @topic.id
  }

  [edit_post: "/post/:post_id/edit"]: respond_to {
    before: =>
      @editing = true

      PostsFlow = require "community.flows.posts"
      @flow = PostsFlow @
      @flow\load_post!

      @topic = @post\get_topic!

      assert_error @post\allowed_to_edit(@user), "invalid post"

    GET: =>
      render: true

    POST: =>
      @flow\edit_post!
      redirect_to: @url_for "topic", topic_id: @topic.id
  }

  [delete_post: "/post/:post_id/delete"]: respond_to {
    before: =>
      PostsFlow = require "community.flows.posts"
      @flow = PostsFlow @
      @flow\load_post!
      @topic = @post\get_topic!

      assert_error @post\allowed_to_edit(@user), "invalid post"

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

  [category: "/category/:category_id"]: capture_errors_json =>
    BrowsingFlow = require "community.flows.browsing"
    @topics = BrowsingFlow(@)\category_topics!
    @user = @category\get_user!
    render: true

  [topic: "/topic/:topic_id"]: capture_errors_json =>
    BrowsingFlow = require "community.flows.browsing"
    @posts = BrowsingFlow(@)\topic_posts!
    render: true

  [user: "/user/:user_id"]: capture_errors_json =>
    import Users, CommunityUsers from require "models"
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

  [index: "/"]: =>
    import Categories from require "models"
    @categories = Categories\select!
    render: true

