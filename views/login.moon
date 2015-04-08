class Login extends require "widgets.base"
  inner_content: =>
    h1 "Login"
    @render_errors!
    form method: "post", ->
      label ->
        strong "Username"
        input type: "text", name: "username"

      button "Log in"


    h2 "Other"
    ul ->
      li ->
        a href: @url_for("register"), "Register"

