# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name __

# ------------------------------------------------------------------------------

static func Get(path, obj):
  if(not obj):
    return null

  if(not path):
    return obj

  var res = obj
  var fields = Array(path.split('.'))

  while(fields.size() > 0):
    var field = fields.pop_front()
    res = res[field]

  return res

# ------------------------------------------------------------------------------

static func Set(value, path, obj):
  if(not path):
    return obj

  if '.' in path:
    var fields = path.split('.')
    var first = fields.pop_front()
    Set(value, String(fields), obj[first])
  else:
    obj[path] = value
