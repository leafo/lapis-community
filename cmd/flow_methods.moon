
exec = (cmd) ->
  f = io.popen cmd
  with f\read("*all")\gsub "%s*$", ""
    f\close!

for mod in exec("ls community/flows/*.moon")\gmatch "([%w_]+)%.moon"
  flow = require "community.flows.#{mod}"
  print flow.__name

  methods = [k for k,v in pairs flow.__base when type(v) == "function"]
  table.sort methods

  for m in *methods
    print "  #{m}"

  print!


