# Components

Ready-made scene components. Most are driven through the
[Router](./router.md), so you rarely instantiate them by hand.

- [Fullscreen loader](#fullscreen-loader)
- [Screen fader](#screen-fader)
- [Blur](#blur)
- [Ask for review](#ask-for-review)
- [Controls test](#controls-test)

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
- `fade_in: bool = false`: `false` fades the rect's alpha to 0 (reveal), `true`
  fades it to 1 (cover)
- `fade_completed` signal: emitted when the tween ends

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

## Controls test

`components/controls-test/controls-test-view.tscn` is a training room for the
input layer: a live timeline of every action, a 4-way direction cross, and one
telemetry gauge per analog stick. It answers the questions every game hits on a
handheld: is this hold coming from the D-pad or from the stick, how deep does
the left trigger really go, how much does this pad drift at rest.

Open it like any other scene:

```gdscript
Router.openScene(preload('res://fox/components/controls-test/controls-test-view.tscn'))
```

The view honours `onOpen(options)` and `onLeave(options)`, so the Router drives
it with no extra glue. It can also be embedded: instantiate it inside a settings
tab or as a debug band over a running level, then drive its area with
`set_view_size(size)` and set `footer_only = true` to draw the timeline alone.
`clear_history()` empties the timeline.

### Extending it by path

The view script declares no global type name, the fox convention for anything a
game subclasses. Extend it by path:

```gdscript
const ControlsTest = preload('res://fox/components/controls-test/controls-test-view.gd')
extends ControlsTest
```

### Theming

Every colour, font and type size comes from a `ControlsTestThemeData` resource
(`components/controls-test/controls-test-theme-data.gd`), never from a game's own
token file. Each field ships a neutral default, so a game that injects nothing
still gets a readable room. Assign `theme_data` before the view enters the tree,
or override `_build_theme()` in a subclass and return the resource; either way
`_ensure_theme()` falls back to the defaults. The base preloads the resource
script as the const `_ThemeData`, which a subclass inherits and should use as the
return type:

```gdscript
func _build_theme() -> _ThemeData:
  var skin = _ThemeData.new()
  skin.accent_keyboard = Color(0.9, 0.4, 0.2)
  skin.accent_stick_left = Color(0.5, 0.3, 1.0)
  skin.font_ui = load('res://assets/fonts/ui.ttf')
  return skin
```

The palette is grouped by input meaning, never by hue, so a timeline card, its
gauge and its benchmark row stay attributable to the same physical source
whatever colours you pick:

- source accents: `accent_keyboard`, `accent_dpad`, `accent_stick_left`,
  `accent_stick_right`
- action accents: `accent_action`, `accent_neutral`, `accent_alert`,
  `accent_focus`, `accent_index`
- surfaces and text: `panel_background`, `text_secondary`, `text_key`,
  `text_value`
- fonts: `font_ui`, `font_body`, both resolved through `ui_font()` and
  `body_font()` which fall back to the engine font when left null
- typography: `size_glyph`, `size_caption`, `size_timing`
- one helper: `secondary_at(alpha)`

### Semantic signals

The base wires itself on the raw [`Controls`](./controls.md) signals only, listed
by `_raw_signal_map()`: `direction_pressed`, `direction_released`,
`stick_direction_changed`, `stick_moved`, `button_pressed`, `button_released`
and `number_pressed`. It knows nothing about any game's interpretation of those
events, so button captions print the Controls action id (`button_a`,
`shoulder_left`, `trigger_left`) rather than a game meaning.

A game that runs a semantic event layer of its own plugs it in by overriding
`_semantic_signal_map()`, which returns `[]` here. Each entry is a
`[Signal, Callable]` pair, and `_input_connections()` concatenates the two lists
so connect and disconnect stay symmetric:

```gdscript
func _semantic_signal_map() -> Array:
  return [
    [EventListener.pawn_focus_started, _on_focus_started],
    [EventListener.pawn_focus_moved, _on_focus_moved],
    [EventListener.pawn_focus_confirmed, _on_focus_confirmed],
    [EventListener.pawn_focus_cancelled, _on_focus_cancelled],
  ]
```

The component's own handlers are meant to be reused that way:
`_on_hold_started`, `_on_hold_ended`, `_on_tapped`, `_on_switched`, `_on_reset`,
`_on_back`, `_on_retrigger`, `_on_focus_started`, `_on_focus_moved`,
`_on_focus_confirmed` and `_on_focus_cancelled`. A game whose semantic layer
already re-emits a raw event can trim the base wiring the same way, by
overriding `_raw_signal_map()`.

Two smaller hooks round it off: `_legend_lines()` returns the two legend lines
printed under the tabs, and `_prev_tab_glyph()` / `_next_tab_glyph()` return the
tab-arrow labels (shoulder labels on a pad, `PG UP` / `PG DN` on a keyboard).

### Reading the stick gauges

Each gauge draws three circles, taken from `STICK_ENGAGE` and `STICK_RELEASE`,
which the view mirrors from `Controls` (`0.5` and `0.25` by default):

- the outer ring is a magnitude of `1.0`, the physical edge of the stick
- the middle ring is `STICK_ENGAGE`, the magnitude at which a direction latches
- the inner ring is `STICK_RELEASE`, below which the direction un-latches

Those two thresholds carve three zones, and the live dot is coloured by the one
it sits in:

- **dead**, below `STICK_RELEASE`: resting drift, no direction. The dot wears
  `text_secondary`
- **hysteresis band**, between `STICK_RELEASE` and `STICK_ENGAGE`: too weak to
  latch a new direction, strong enough to keep the current one. The dot wears
  `accent_focus`
- **live**, at or above `STICK_ENGAGE`: the direction latches. The dot wears
  `accent_dpad`

The faint dot trail behind the live dot is the jitter history, which is what
reveals drift at rest. The metrics under each gauge read `X`, `Y`, `MAG`, `ANG`,
`ZONE` and `DIR`. The same three-zone language graduates the analog trigger bars
drawn above each stick, so a pad whose trigger never reaches `STICK_ENGAGE` is
visible at a glance.

### Benchmark tab

The second tab (`VIEWS` holds `inputs` and `benchmark`, the shoulders or
`PG UP` / `PG DN` switch between them) runs `movement-benchmark.gd`, a headless
simulation of a grid pawn's rush model fed by the same events as the timeline.
It measures cadence per input source and mode (`cells_per_push`, `cells_per_s`),
and compares candidate stick-response models side by side through `model_cells`
and `model_cps`. Its constants are plain variables (`cancel_ms`, `arm_ms`,
`repeat_initial_ms`, `repeat_interval_ms`, `TRACK_CELLS`), so a game can tune
them without touching gameplay code, and `reset_metrics()` clears the table.
