# HTTP

`HTTP` is a thin wrapper around Godot's `HTTPRequest` for talking to a REST API.
It creates the request node for you, sets JSON headers, serializes dictionary
bodies, and routes the result to `onComplete` / `onError` callbacks.

## Configuration

`HTTP` reads two project settings once at load:

- `custom/api-url` → base URL, prepended to `endpoint`
- `custom/api-key` → sent as the `x-api-key` header

Set them in `project.godot`:

```ini
[custom]

api-url="https://api.your-game.com"
api-key="your-api-key"
```

## API

- `HTTP.Get(caller, options)`
- `HTTP.Post(caller, options)`
- `HTTP.Put(caller, options)`

`caller` is the node the temporary `HTTPRequest` is attached to (usually
`self`). `options` is a dictionary:

| key | description |
|-----|-------------|
| `endpoint` | path appended to `custom/api-url` (e.g. `/score`) |
| `url` | full URL — overrides `endpoint` + base url |
| `body` | request body; a `Dictionary` is JSON-stringified automatically |
| `onComplete` | `func(result, response_code, headers, body)` on success |
| `onError` | `func(result, response_code, headers, body)` on transport error |

The callbacks receive the raw Godot
[`request_completed`](https://docs.godotengine.org/en/stable/classes/class_httprequest.html#signals)
arguments. `body` is a `PackedByteArray` — decode it with
`body.get_string_from_utf8()`.

## Example

```gdscript
Router.showLoader()

HTTP.Post(self, {
  endpoint = "/score",
  body = {playerId = "FieryFox", score = 100},
  onError = func(_result, _response_code, _headers, _body):
    handleScoreFailure()
    Router.hideLoader()
  ,
  onComplete = func(_result, _response_code, _headers, body):
    var payload = body.get_string_from_utf8()
    var newRecord = __.GetOr(false, 'newRecord', payload)
    G.debug('✅ [b][color=green]score posted[/color][/b]', {newRecord = newRecord})
    Router.hideLoader()
})
```
