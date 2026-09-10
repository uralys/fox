extends Node

# ==============================================================================
# FrameProbe — the frame-time instrument, and the only one a game needs.
#
# "It stutters" is not a measurement, and on the web there is nowhere to take one:
# the Godot editor cannot attach a remote profiler to a wasm build, `--verbose`
# says nothing about frames, and a browser's own tools see one opaque canvas. What
# a browser DOES give back, faithfully and for free, is `print()` — which a CDP
# console harness already streams. So the instrument is a printer, and its output
# is grepable key=value lines.
#
# It answers three questions, in this order:
#   - WHERE does it hitch? every report is scoped to the screen that was up, and
#     every spike names it;
#   - is it SCRIPT or DRAWING? `proc` is the GDScript half of the frame, `draws`
#     the number of draw calls the renderer issued — a screen at 30 fps with a
#     0.4 ms process time is a rendering problem and no amount of GDScript
#     optimisation will move it;
#   - is it the WEB or the game? the same probe runs on desktop, so every number
#     has a baseline to be read against.
#
# ⛔ OFF unless asked. It costs nothing when idle (`set_process(false)`), and
# switching it on is deliberate:
#   - desktop: FOX_FRAME_PROBE=1 in the environment;
#   - browser: `?probe=1` in the url, or `localStorage.foxFrameProbe = 1` then
#     reload — which is how a slowdown gets measured on the real published page,
#     in the real build, on the machine that actually stutters;
#   - browser, WITHOUT devtools: `localStorage.foxFrameProbe = 'hud'` (or
#     `?probe=hud`) adds a corner readout on top of the console lines. A published
#     web build is often an iframe whose console a player never opens; a line of
#     text in the corner is read at a glance while playing, which is what a report
#     from a real machine needs to be;
#   - from code: `FrameProbe.enable()`.
#
# It is deliberately NOT a debug flag: a game's debug switches are usually forced
# off in the very build it ships, and that build is the one players run.
# ==============================================================================

const TAG := '[perf] '

# A frame is a SPIKE past this many budgets. 2.0 is a dropped frame — the hitch a
# player feels — rather than the millisecond of noise every frame carries.
const SPIKE_FACTOR := 2.0

# At most this many spike lines per window. A screen that drops every frame would
# otherwise fill the console with its own symptom AND slow down what it measures;
# past the cap spikes are still counted, only silent.
const MAX_SPIKE_LINES := 12

# A rolling report even when the screen never changes, so a long session on a
# published page leaves a trail instead of a single line at the very end.
const HEARTBEAT_S := 10.0

# ~5 minutes at 60 fps. Bounded on purpose: this runs inside a browser tab.
const MAX_SAMPLES := 20000

const DEFAULT_BUDGET_MS := 1000.0 / 60.0

# The readout averages over the last ~2 seconds rather than over the whole screen
# window: a player looking at it wants to know how the game feels NOW, not how it
# felt since the level opened.
const HUD_SAMPLES := 120

# The on-screen readout refreshes at this cadence. A per-frame label would make
# the instrument part of what it measures: a `draw_string` every frame is exactly
# the kind of cost this probe exists to find.
const HUD_REFRESH_S := 0.5

# ------------------------------------------------------------------------------

var enabled := false

var _budget_ms := DEFAULT_BUDGET_MS
var _label := 'boot'
var _phase := ''
var _scene_id := 0

var _frames := PackedFloat32Array()
var _procs := PackedFloat32Array()
var _draws := PackedInt32Array()
var _objects := PackedInt32Array()
var _prims := PackedInt32Array()

var _count := 0
var _dropped := 0
var _spikes := 0
var _spike_lines := 0
var _first_ms := 0.0
var _window_s := 0.0
var _since_heartbeat := 0.0

var _hud: Label = null
var _since_hud := 0.0
var _recent := PackedFloat32Array()

# ------------------------------------------------------------------------------

func _ready() -> void:
	set_process(false)
	var asked := _asked_for()
	if asked != '':
		enable()
		# `hud` is the mode meant for a REAL published page: the console is behind a
		# devtools panel nobody opens while playing, whereas a corner readout is
		# read at a glance, on the machine that actually stutters.
		if asked == 'hud':
			show_hud()

# The switch is read once, at boot, from wherever the platform can carry it. On
# web BOTH channels matter: the url param is what a harness controls, localStorage
# is what a player can set in a devtools console on a page whose url is an iframe
# nobody can add a query string to.
# Returns '' (off), 'on' (console only) or 'hud' (console + on-screen readout).
func _asked_for() -> String:
	var from_env := OS.get_environment('FOX_FRAME_PROBE')
	if from_env == 'hud':
		return 'hud'
	if from_env == '1':
		return 'on'
	if not OS.has_feature('web'):
		return ''
	var asked = JavaScriptBridge.eval('(function(){try{'
		+ 'var q = location.search, s = localStorage.getItem("foxFrameProbe") || "";'
		+ 'if (q.indexOf("probe=hud") >= 0 || s === "hud") return "hud";'
		+ 'if (q.indexOf("probe=1") >= 0 || s) return "on";'
		+ 'return "";'
		+ '}catch(e){return ""}})()', true)
	return str(asked)

func enable() -> void:
	if enabled:
		return
	enabled = true

	# The refresh rate is the honest budget on a 120 Hz panel or a docked Deck, but
	# a headless browser reports -1 and a vsync-less run reports 0 — both fall back
	# to 60, which is what a game targets anyway.
	var refresh := DisplayServer.screen_get_refresh_rate()
	if refresh > 1.0:
		_budget_ms = 1000.0 / refresh

	_reset()
	set_process(true)
	prints(TAG + 'probe ON', 'budget=%.2fms' % _budget_ms, 'renderer=' + _renderer(),
		'platform=' + _platform(), 'threads=' + str(_threads_available()))

func disable() -> void:
	if not enabled:
		return
	report('disable')
	enabled = false
	set_process(false)

# ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_watch_scene()

	var ms := delta * 1000.0
	var proc_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	# Draw calls alone cannot say WHY one level costs twice another with the same
	# node count. `objects` counts what the renderer submitted, `prims` the
	# triangles behind it: a level heavy in objects is a batching problem, a level
	# heavy in primitives is a geometry problem, and the two are fixed differently.
	var objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

	if _count == 0:
		# The FIRST frame of a screen is its own measurement: it carries the shader
		# compilations, the resource loads and the layout pass that no later frame
		# pays again, and it is the single most common source of a felt hitch.
		_first_ms = ms
	_count += 1
	_window_s += delta

	if _frames.size() < MAX_SAMPLES:
		_frames.append(ms)
		_procs.append(proc_ms)
		_draws.append(draws)
		_objects.append(objects)
		_prims.append(prims)
	else:
		_dropped += 1

	if ms > _budget_ms * SPIKE_FACTOR:
		_spikes += 1
		if _spike_lines < MAX_SPIKE_LINES:
			_spike_lines += 1
			prints(TAG + 'spike', 'screen=' + _screen_label(), 't=%.2f' % _window_s,
				'ms=%.1f' % ms, 'proc=%.2f' % proc_ms, 'draws=%d' % draws,
				'frame=%d' % _count)

	_since_heartbeat += delta
	if _since_heartbeat >= HEARTBEAT_S:
		report('heartbeat')

	if _hud != null:
		_recent.append(ms)
		if _recent.size() > HUD_SAMPLES:
			_recent = _recent.slice(_recent.size() - HUD_SAMPLES)
		_since_hud += delta
		if _since_hud >= HUD_REFRESH_S:
			_since_hud = 0.0
			_refresh_hud(draws)

# A screen change is detected on the INSTANCE ID rather than on the node, so a
# reference to an already freed screen is never dereferenced, and rather than on
# its name, so two visits to the same screen stay two separate windows.
func _watch_scene() -> void:
	var scene = Router.currentScene if Router != null else null
	var id := 0 if scene == null else int(scene.get_instance_id())
	if id == _scene_id:
		return
	if _count > 0:
		report('leave')
	_scene_id = id
	_label = 'none' if scene == null else str(scene.name)
	_phase = ''
	_reset()

# ------------------------------------------------------------------------------

# One line per window, every number a `key=value` pair — a verdict script parses
# it with a split and nothing else.
func report(reason: String) -> void:
	_since_heartbeat = 0.0
	if _count < 5:
		return

	var frames := _frames.duplicate()
	frames.sort()
	var procs := _procs.duplicate()
	procs.sort()
	var draws := _draws.duplicate()
	draws.sort()
	var objects := _objects.duplicate()
	objects.sort()
	var prims := _prims.duplicate()
	prims.sort()

	prints(TAG + 'window', 'screen=' + _screen_label(), 'reason=' + reason,
		'frames=%d' % _count, 'secs=%.1f' % _window_s,
		'fps=%.1f' % (_count / maxf(_window_s, 0.001)),
		'p50=%.1f' % _at(frames, 0.50), 'p95=%.1f' % _at(frames, 0.95),
		'p99=%.1f' % _at(frames, 0.99), 'max=%.1f' % _at(frames, 1.0),
		'first=%.1f' % _first_ms,
		'proc50=%.2f' % _at(procs, 0.50), 'proc95=%.2f' % _at(procs, 0.95),
		'draws50=%d' % int(_at_int(draws, 0.50)), 'draws95=%d' % int(_at_int(draws, 0.95)),
		'objects95=%d' % int(_at_int(objects, 0.95)),
		'prims95=%d' % int(_at_int(prims, 0.95)),
		'spikes=%d' % _spikes, 'budget=%.2f' % _budget_ms,
		'nodes=%d' % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		'mem=%.1f' % (float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0),
		'unsampled=%d' % _dropped)

# Annotate the stream from a scenario ("this is where the level starts"), so a
# report can be read against what the game was doing.
func mark(label: String) -> void:
	if enabled:
		prints(TAG + 'mark', label, 't=%.2f' % _window_s, 'screen=' + _screen_label())

# Close the current window and open one under a new phase, WITHOUT a screen change.
# Standing still and walking a pawn are two different costs on the same screen, and
# a single window averages them into a number that describes neither.
func split(phase: String) -> void:
	if not enabled:
		return
	report('split')
	_phase = phase
	_reset()

func _screen_label() -> String:
	return _label if _phase.is_empty() else _label + '/' + _phase

# ------------------------------------------------------------------------------

func _reset() -> void:
	_frames = PackedFloat32Array()
	_procs = PackedFloat32Array()
	_draws = PackedInt32Array()
	_objects = PackedInt32Array()
	_prims = PackedInt32Array()
	_count = 0
	_dropped = 0
	_spikes = 0
	_spike_lines = 0
	_first_ms = 0.0
	_window_s = 0.0
	_since_heartbeat = 0.0

func _at(sorted: PackedFloat32Array, quantile: float) -> float:
	if sorted.is_empty():
		return 0.0
	var index := int(round(quantile * (sorted.size() - 1)))
	return sorted[clampi(index, 0, sorted.size() - 1)]

func _at_int(sorted: PackedInt32Array, quantile: float) -> int:
	if sorted.is_empty():
		return 0
	var index := int(round(quantile * (sorted.size() - 1)))
	return sorted[clampi(index, 0, sorted.size() - 1)]

# ------------------------------------------------------------------------------
# On-screen readout — the instrument for the page nobody can attach a profiler to
# ------------------------------------------------------------------------------

# Its own CanvasLayer, above every screen and outside the game's `content_scale`
# concerns, so no screen change and no responsive factor can hide it or resize it.
# Built lazily: a probe running in `on` mode never pays for a Label.
func show_hud() -> void:
	if _hud != null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 128
	layer.name = 'frameProbeHud'

	_hud = Label.new()
	_hud.name = 'readout'
	_hud.position = Vector2(8, 8)
	_hud.add_theme_font_size_override('font_size', 13)
	_hud.add_theme_color_override('font_color', Color(0.6, 1.0, 0.9))
	# An outline rather than a background panel: no full-width quad blended over
	# the game on every frame of every screen.
	_hud.add_theme_color_override('font_outline_color', Color(0, 0, 0, 0.9))
	_hud.add_theme_constant_override('outline_size', 4)
	_hud.text = TAG
	layer.add_child(_hud)

	# Deferred: an autoload's `_ready` runs while the tree root is still being
	# built, and adding a child to it there is what turns a probe into a crash.
	get_tree().root.add_child.call_deferred(layer)

func _refresh_hud(draws: int) -> void:
	var sorted := _recent.duplicate()
	sorted.sort()
	var p50 := _at(sorted, 0.50)
	var p95 := _at(sorted, 0.95)
	_hud.text = '%s  %.0f fps  p50 %.1f  p95 %.1f  draws %d  nodes %d' % [
		_screen_label(), 1000.0 / maxf(p50, 0.001), p50, p95, draws,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]
	# Green while every frame fits the budget, amber past it, red past two: the
	# colour is the reading, the numbers are the proof.
	var colour := Color(0.6, 1.0, 0.9)
	if p95 > _budget_ms * SPIKE_FACTOR:
		colour = Color(1.0, 0.45, 0.45)
	elif p95 > _budget_ms:
		colour = Color(1.0, 0.85, 0.4)
	_hud.add_theme_color_override('font_color', colour)

# ------------------------------------------------------------------------------

# A web build runs on the `.web` override (gl_compatibility, i.e. WebGL2), not on
# the desktop value: reporting the base setting would label every browser run
# `forward_plus` and quietly invite the wrong conclusion.
func _renderer() -> String:
	var method := str(ProjectSettings.get_setting('rendering/renderer/rendering_method', '?'))
	if OS.has_feature('web'):
		method = str(ProjectSettings.get_setting('rendering/renderer/rendering_method.web', method))
	return method

func _platform() -> String:
	return 'web' if OS.has_feature('web') else OS.get_name().to_lower()

# On web this is the question behind half the stutters: without cross-origin
# isolation there is no SharedArrayBuffer, so the export has no threads and audio
# mixing shares the one thread that also draws. Reported, never acted upon here.
func _threads_available() -> bool:
	if not OS.has_feature('web'):
		return true
	return bool(JavaScriptBridge.eval('typeof SharedArrayBuffer !== "undefined" ? 1 : 0', true))
