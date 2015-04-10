import Widget from require "lapis.html"

import underscore, time_ago_in_words from require "lapis.util"

import random from math

class Base extends Widget
  @widget_name: => underscore @__name or "some_widget"
  base_widget: true

  inner_content: =>

  content: (fn=@inner_content) =>
    classes = @widget_classes!

    local inner
    classes ..= " base_widget" if @base_widget

    @_opts = { class: classes, -> raw inner }

    if @js_init
      @widget_id!
      @content_for "js_init", -> raw @js_init!

    inner = capture -> fn @
    element @elm_type or "div", @_opts

  widget_classes: =>
    @css_class or @@widget_name!

  widget_id: =>
    unless @_widget_id
      @_widget_id = "#{@@widget_name!}_#{random 0, 100000}"
      @_opts.id or= @_widget_id if @_opts
    @_widget_id

  widget_selector: =>
    "'##{@widget_id!}'"


  render_errors: =>
    return unless @errors and next @errors
    h3 "There was an errror"
    ul ->
      for e in *@errors
        li e

  dump: (thing) =>
    pre require("moon").dump thing

