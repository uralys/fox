# Frame probe

`FrameProbe` is an autoload (`fox/core/frame-probe.gd`) that measures frame time
and prints it as grepable `key=value` lines.

"It stutters" is not a measurement, and on the web there is nowhere to take one:
the Godot editor cannot attach a remote profiler to a wasm build, `--verbose`
says nothing about frames, and a browser's own tools see one opaque canvas. What
a browser does give back, faithfully and for free, is `print()`. So the
instrument is a printer.

Register it in your project's `[autoload]` section:

```ini
[autoload]

FrameProbe="*res://fox/core/frame-probe.gd"
```

The probe scopes every measurement to the screen that was up, reading
`Router.currentScene`, so a report always names where the hitch happened. It has
no other coupling to your game.

- [Switching it on](#switching-it-on): the activation matrix, off by default
- [Reading the output](#reading-the-output): the `[perf] key=value` lines
- [Spikes](#spikes): `SPIKE_FACTOR` and the per window cap
- [Heartbeat](#heartbeat): a rolling report on a screen that never changes
- [On-screen readout](#on-screen-readout): the HUD mode
- [Annotating a run](#annotating-a-run): `mark()` and `split()`
- [Web versus desktop](#web-versus-desktop): how to read the two against each other

## Switching it on

**The probe is off unless asked.** `_ready()` calls `set_process(false)` and only
enables the probe when one of the switches below is set, so an untouched build
pays nothing at all: no sampling, no allocation, no `Label`.

The switch is read once, at boot, from wherever the platform can carry it.

| Where | Switch | Mode |
| --- | --- | --- |
| Desktop env | `FOX_FRAME_PROBE=1` | console |
| Desktop env | `FOX_FRAME_PROBE=hud` | console + readout |
| Web url | `?probe=1` | console |
| Web url | `?probe=hud` | console + readout |
| Web storage | `localStorage.foxFrameProbe = 1` | console |
| Web storage | `localStorage.foxFrameProbe = 'hud'` | console + readout |
| From code | `FrameProbe.enable()` | console |

On desktop:

```sh
FOX_FRAME_PROBE=1 fox run:game
```

On the web both channels matter. The url param is what an automated harness
controls; `localStorage` is what a player can set from a devtools console on a
page whose url is an iframe nobody can add a query string to:

```txt
localStorage.foxFrameProbe = 'hud'
```

Then reload. This is how a slowdown gets measured on the real published page, in
the real build, on the machine that actually stutters.

From code, `enable()` and `disable()` bracket a scenario. `disable()` closes the
current window with a final report before it stops:

```gdscript
FrameProbe.enable()
await someScenario()
FrameProbe.disable()
```

> ⚠️ This is deliberately not a debug flag. Debug switches are usually forced off
> in the very build a game ships, and that build is the one players run: the
> probe has to stay reachable there.

## Reading the output

Every line starts with the `[perf]` tag, so the whole stream is one
grep away, and every number is a `key=value` pair a script can parse with a split
and nothing else.

Enabling the probe prints its own conditions first:

```txt
[perf] probe ON budget=16.67ms renderer=forward_plus platform=macos threads=true
```

`budget` is the frame budget in milliseconds, taken from
`DisplayServer.screen_get_refresh_rate()`: the honest budget on a 120 Hz panel or
a docked Steam Deck. A headless browser reports `-1` and a vsync-less run reports
`0`, and both fall back to 60 fps.

One `window` line is then printed per screen, per phase, and per heartbeat. It is
a single line; it is wrapped here to stay readable:

```txt
[perf] window screen=level/playing reason=leave frames=612 secs=10.2
  fps=60.0 p50=16.6 p95=17.9 p99=24.1 max=41.3 first=88.2
  proc50=0.31 proc95=0.55 draws50=142 draws95=151
  objects95=210 prims95=48221 spikes=2 budget=16.67
  nodes=486 mem=74.3 unsampled=0
```

| Key | What it says |
| --- | --- |
| `screen` | the screen that was up, plus the phase if one was set |
| `reason` | why the window closed: `leave`, `heartbeat`, `split` or `disable` |
| `frames`, `secs`, `fps` | the size of the window and its average rate |
| `p50`, `p95`, `p99`, `max` | frame time percentiles, in milliseconds |
| `first` | the very first frame of the screen, in milliseconds |
| `proc50`, `proc95` | the GDScript half of the frame, in milliseconds |
| `draws50`, `draws95` | draw calls the renderer issued |
| `objects95`, `prims95` | objects submitted, and triangles behind them |
| `spikes` | frames past the spike threshold |
| `budget` | the frame budget the numbers are read against |
| `nodes`, `mem` | node count and static memory, in megabytes |
| `unsampled` | frames dropped once `MAX_SAMPLES` was reached |

The pair that settles most arguments is `proc` against `draws`. A screen at
30 fps with a `proc95` of 0.4 ms is a rendering problem, and no amount of
GDScript optimisation will move it. Then `objects95` against `prims95` splits
rendering in two: a level heavy in objects is a batching problem, a level heavy
in primitives is a geometry problem, and the two are fixed differently.

`first` deserves its own reading. The first frame of a screen carries the shader
compilations, the resource loads and the layout pass that no later frame pays
again, and it is the single most common source of a felt hitch.

A window shorter than 5 frames prints nothing: it would describe noise.

The sample buffers are capped at `MAX_SAMPLES` (20000, about 5 minutes at
60 fps) because this runs inside a browser tab. Past the cap, frames are counted
in `unsampled` but no longer stored.

## Spikes

A frame is a spike when it costs more than `SPIKE_FACTOR` budgets. The factor is
`2.0`: a dropped frame, the hitch a player actually feels, rather than the
millisecond of noise every frame carries.

```txt
[perf] spike screen=level/playing t=4.82 ms=41.3 proc=0.44 draws=151 frame=289
```

`t` is the time in seconds since the window opened, and `frame` its index, so a
spike can be placed against whatever the game was doing.

At most `MAX_SPIKE_LINES` (12) spike lines are printed per window. A screen that
drops every frame would otherwise fill the console with its own symptom and slow
down the very thing it measures. Past the cap spikes are still counted in the
`spikes` field of the window line, only silent.

## Heartbeat

A window normally closes when the screen changes. `HEARTBEAT_S` (10 seconds)
forces a rolling `window` line even when it never does, so a long session leaves
a trail instead of a single line at the very end. Those lines carry
`reason=heartbeat`.

Screen changes are detected on the instance id rather than on the node, so a
reference to an already freed screen is never dereferenced, and rather than on
the name, so two visits to the same screen stay two separate windows.

## On-screen readout

`hud` mode adds a corner readout on top of the console lines. A published web
build is often an iframe whose console a player never opens, whereas a line of
text in the corner is read at a glance while playing, which is what a report from
a real machine needs to be.

```gdscript
FrameProbe.show_hud()
```

The readout averages over `HUD_SAMPLES` (120 frames, about 2 seconds) rather than
over the whole window: a player looking at it wants to know how the game feels
now, not how it felt since the level opened. It refreshes every `HUD_REFRESH_S`
(0.5 s), because a `draw_string` on every frame is exactly the kind of cost this
probe exists to find.

Its colour is the reading and the numbers are the proof: green while every frame
fits the budget, amber past it, red past `SPIKE_FACTOR` budgets.

The readout lives on its own `CanvasLayer` above every screen, outside the
`content_scale` concerns, so no screen change and no responsive factor can hide
it or resize it. It is built lazily: a probe running in console mode never pays
for a `Label`.

## Annotating a run

`mark(label)` prints a one-off annotation into the stream, so a report can be
read against what the game was doing:

```gdscript
FrameProbe.mark('level started')
```

```txt
[perf] mark level started t=1.20 screen=level
```

`split(phase)` closes the current window and opens one under a new phase, without
a screen change. Standing still and walking a pawn are two different costs on the
same screen, and a single window averages them into a number that describes
neither:

```gdscript
FrameProbe.split('playing')
```

From there every line reads `screen=level/playing` until the next split or screen
change.

## Web versus desktop

The same probe runs on both, which is the point: every web number has a desktop
baseline to be read against, and the question "is it the web or is it the game?"
gets an answer instead of an opinion.

Two fields on the `probe ON` line carry the web specifics:

- `renderer` reports the `.web` override (`gl_compatibility`, meaning WebGL2)
  rather than the desktop setting. Reporting the base value would label every
  browser run `forward_plus` and quietly invite the wrong conclusion.
- `threads` answers the question behind half the web stutters. Without
  cross-origin isolation there is no `SharedArrayBuffer`, so the export has no
  threads and audio mixing shares the one thread that also draws. The probe
  reports it and never acts on it.
