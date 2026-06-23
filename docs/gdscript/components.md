# Components

Ready-made scene components. Most are driven through the
[Router](./router.md), so you rarely instantiate them by hand.

- [Fullscreen loader](#fullscreen-loader)
- [Screen fader](#screen-fader)
- [Blur](#blur)
- [Ask for review](#ask-for-review)

## Fullscreen loader

A blurring fullscreen overlay shown during async work (HTTP calls, scene
loading). Drive it from the Router:

```gdscript
Router.showLoader()
# ... await your async work ...
Router.hideLoader()
```

It animates a spinner in and ramps a blur shader up while showing, then ramps it
down and frees itself on `hideLoader()`. The blur depth is the `lod` export
(default `3.0`).

## Screen fader

A fade-to-color overlay for screen transitions, added on top of the current
scene:

```gdscript
Router.useScreenFader(0.75)   # fade out over 0.75s
```

The component (`components/screen-fader.tscn`) exposes:

- `duration: float = 1`
- `fade_in: bool = false` — `false` fades the rect's alpha to 0 (reveal), `true`
  fades it to 1 (cover)
- `fade_completed` signal — emitted when the tween ends

Add it directly to a scene if you want to await the signal yourself.

## Blur

`components/blur.tscn` is a reusable blur surface backed by a shader
(`blur_amount` parameter). [Popups](./popups.md) and the fullscreen loader use it
to blur their background; name an instance `blur` inside a popup to have it
shown/hidden automatically.

## Ask for review

`components/review/ask-for-review.tscn` is a popup that prompts the player to
rate the game. It extends the [popup](./popups.md) base and adapts to the
platform:

- **Android**: uses the `GodotAndroidRateme` in-app review flow if present;
- **iOS**: uses the `InappReviewPlugin` review flow if present;
- **fallback**: shows a "Rate now" button that opens the store URL
  (via [`Bundle`](./utils.md#bundle)).

```gdscript
var AskForReview = preload('res://fox/components/review/ask-for-review.tscn')

func askReview():
  var popup = AskForReview.instantiate()
  # popup.useForLandscape()   # optional landscape placement
  $/root/app/popups.add_child(popup)
```

On completion it calls `Player.setRatingDone()` and closes. It expects a
`Player` autoload and a `please rate this app` translation key.
