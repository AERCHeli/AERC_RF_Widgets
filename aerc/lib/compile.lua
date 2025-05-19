local compiler = {}

function compiler.loadfile(path)
  return assert(loadfile(path))
end

return compiler
