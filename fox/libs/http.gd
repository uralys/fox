# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name HTTP

# ------------------------------------------------------------------------------

static func Get(caller, options):
  var subURL = __.GetOr('', 'url' ,options)
  var onComplete = __.Get('onComplete', options)

  var apiUrl = ProjectSettings.get_setting('api/url')
  var url = apiUrl + subURL

  var http = HTTPRequest.new()
  caller.add_child(http)

  if(onComplete):
    http.connect('request_completed', Callable(caller,onComplete))

  var API_KEY = ProjectSettings.get_setting('api/key')

  http.request(
    url,
    ['x-api-key:' + API_KEY]
  )
