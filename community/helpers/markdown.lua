local cmark, discount
if pcall(function()
  cmark = require("cmark")
end) then
  return {
    cmark = cmark,
    markdown_to_html = function(markdown)
      local opts = cmark.OPT_VALIDATE_UTF8 + cmark.OPT_NORMALIZE + cmark.OPT_SMART + cmark.OPT_UNSAFE
      local document = assert(cmark.parse_string(markdown, opts))
      return cmark.render_html(document, opts)
    end
  }
end
if pcall(function()
  discount = require("discount")
end) then
  return {
    discount = discount,
    markdown_to_html = function(markdown)
      return discount(markdown)
    end
  }
end
return error("failed to find a markdown library (tried cmark, discount)")
