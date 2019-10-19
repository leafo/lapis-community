local cmark, discount

if pcall -> cmark = require "cmark"
  return {
    :cmark
    markdown_to_html: (markdown) ->
      opts = cmark.OPT_VALIDATE_UTF8 +
        cmark.OPT_NORMALIZE +
        cmark.OPT_SMART +
        cmark.OPT_UNSAFE -- sanitization is up to the renderer

      document = assert cmark.parse_string markdown, opts
      cmark.render_html document, opts
  }

if pcall -> discount = require "discount"
  return {
    :discount
    markdown_to_html: (markdown) ->
      discount markdown
  }

error "failed to find a markdown library (tried cmark, discount)"
