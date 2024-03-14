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
  var onError = __.Get('onError', options)

  var url = API_URL + subURL

  var http = HTTPRequest.new()
  caller.add_child(http)

  var _onComplete = func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
    if(result != OK):
      G.log('❌ [b][color=pink]Error with HTTPRequest[/color][/b]', {url=url, result=result}, 'see https://docs.godotengine.org/en/stable/classes/class_httprequest.html#enumerations')
      if(onError):
        onError.call(result, response_code, headers, body)
        return

    if(onComplete):
      onComplete.call(result, response_code, headers, body)

  http.request_completed.connect(_onComplete)
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
