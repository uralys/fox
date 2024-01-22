# ------------------------------------------------------------------------------

extends Node

# ------------------------------------------------------------------------------

class_name HTTP

# ------------------------------------------------------------------------------

static var API_URL = ProjectSettings.get_setting('custom/api-url')
static var API_KEY = ProjectSettings.get_setting('custom/api-key')

# ------------------------------------------------------------------------------

static func _createHTTPRequest(caller, options):
  var subURL = __.GetOr('', 'url' ,options)
  var onComplete = __.Get('onComplete', options)

  var url = API_URL + subURL

  var http = HTTPRequest.new()
  caller.add_child(http)

  if(onComplete):
    http.request_completed.connect(onComplete)

  return {http=http, url=url}

# ------------------------------------------------------------------------------

static func _performRequest(caller, options, method):
  var httpRequest = _createHTTPRequest(caller, options)
  var body = __.GetOr("", 'body', options)
  var http = httpRequest.http
  var url = httpRequest.url

  http.request(
    url,
    ['x-api-key:' + API_KEY],
    method,
    body
  )

# ------------------------------------------------------------------------------

static func Get(caller, options):
  _performRequest(caller, options, HTTPClient.METHOD_GET)

# ------------------------------------------------------------------------------

static func Post(caller, options):
  _performRequest(caller, options, HTTPClient.METHOD_POST)

# ------------------------------------------------------------------------------

static func Put(caller, options):
  _performRequest(caller, options, HTTPClient.METHOD_PUT)
