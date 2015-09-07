local is_empty_html
is_empty_html = function(str)
  if str:match("%<[iI][mM][gG]%s") then
    return false
  end
  local out = (str:gsub("%<.-%>", ""):gsub("&nbsp;", ""))
  return not not out:find("^%s*$")
end
return {
  is_empty_html = is_empty_html
}
