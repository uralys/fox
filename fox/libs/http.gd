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
    http.connect('request_completed', caller, onComplete)

  http.request(
    url,
    ['x-api-key:'+ProjectSettings.get_setting('api/key')]
  )
