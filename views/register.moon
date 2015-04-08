class Register extends require "widgets.base"
  inner_content: =>
    h1 "Register"
    @render_errors!
    form method: "post", ->
      label ->
        strong "Username"
        input type: "text", name: "username"

      button "New account"

