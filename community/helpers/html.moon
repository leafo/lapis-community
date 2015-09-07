is_empty_html = (str) ->
  -- has an image, not empty
  return false if str\match "%<[iI][mM][gG]%s"

  -- only whitespace after html tags removed
  out = (str\gsub("%<.-%>", "")\gsub("&nbsp;", ""))
  not not out\find "^%s*$"

{ :is_empty_html }
