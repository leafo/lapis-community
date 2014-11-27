
import Flow from require "lapis.flow"

import Categories, Topics, Posts, Users from require "models"

import assert_error, yield_error from require "lapis.application"
import assert_valid from require "lapis.validate"

date = require "date"

class Categories extends Flow
  new: (req) =>
    super req
    assert @current_user, "missing current user for post flow"

  find_category: =>
    assert_valid @params, {
      {"category_id", is_integer: true}
    }

    @category = Categories\find @params.category_id
    assert_error @category, "invalid category"

  show_members: =>
    @find_category!
