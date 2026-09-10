extends CanvasLayer

# ==============================================================================
# splash-screen.gd — the boot logo of a fox game, and its INVISIBLE handoff.
#
# The player sees one logo twice: first drawn by the platform while the engine
# comes up (the HTML loading page on web, the boot splash window on desktop and
# on the Deck), then drawn by the game in this scene. The whole point is that
# they cannot tell where one stops and the other starts.
#
# ── ONE RULE, THREE SURFACES ──
#
#   the logo measures LOGO_BASE_WIDTH on the BASE_CANVAS of the project,
#   and that frame is CONTAINED in the window.
#
#   * `fox/assets/splash/boot-splash.png` IS that frame: 1920x1080 black with the
#     logo laid at 920px in its centre. `project.godot` names it in
#     `boot_splash/image` with `show_image=true`, so Steam, macOS, Windows and the
#     Steam Deck show it at boot, and the web shell exports it as `index.png`
#     with the same contain rule.
#   * this scene applies the same formula:
#     `LOGO_BASE_WIDTH * FoxResponsive.contain_fit(screen, BASE_CANVAS)`.
#     No screen ratio, no cap — the same contain, therefore the same result.
#   * it starts ALREADY OPAQUE, on every platform: the previous surface was
#     showing this very logo, and fading it in again would blink the handoff.
#
# The two rules meet to the pixel everywhere, `content_scale_factor` included (it
# appears once in the numerator and once in the denominator, and cancels out):
#
#   window (physical px)         boot    in-game
#   desktop 1080p 1920x1080      920.0      920.0
#   desktop 1440p 2560x1440     1226.7     1226.7
#   desktop 4K   3840x2160      1840.0     1840.0
#   Steam Deck   1280x800        613.3      613.3
#   itch embed    960x600        460.0      460.0
#
# ⚠️ The web loading page needs ONE more thing, which lives in the game's export
# preset rather than here: the progress bar. See
# `fox/components/splash/web-head-include.html` — the snippet to paste into the
# web preset's `html/head_include`.
#
# Usage (from the game's App, which extends fox/core/app.gd):
#
#   var splash = startSplash()
#   if splash: await splash.splashFinished
# ==============================================================================

signal splashFinished

const _Responsive := preload('res://fox/screens/responsive.gd')

const DEFAULT_LOGO_PATH := 'res://fox/assets/splash/logo-uralys.png'
const ELECTRIC_SHADER := preload('res://fox/shaders/splash-electric.gdshader')

const BASE_CANVAS := Vector2(1920.0, 1080.0)
const LOGO_BASE_WIDTH := 920.0

# Logo is held fully visible for this long before the end sequence.
const LOGO_HOLD := 1.65

# Electric crackle + fade-out span this long, right before the splash exits.
const ELECTRIC_LEAD := 0.8

# Logo swells by this fraction at peak crackle intensity.
const LOGO_GROW := 0.12

# The game may point this at its own logo; the boot-splash frame has to be
# regenerated to match (see docs).
var logo_path: String = DEFAULT_LOGO_PATH

var logo: TextureRect

# ------------------------------------------------------------------------------

func _ready() -> void:
	layer = 128
	_build()
	_animate()
	get_viewport().size_changed.connect(_layout_logo)

# ------------------------------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	logo = TextureRect.new()
	logo.texture = load(logo_path)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var electric := ShaderMaterial.new()
	electric.shader = ELECTRIC_SHADER
	electric.set_shader_parameter('intensity', 0.0)
	logo.material = electric

	add_child(logo)
	_layout_logo()

# ------------------------------------------------------------------------------

func _layout_logo() -> void:
	if logo == null or logo.texture == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var texture_size: Vector2 = logo.texture.get_size()
	var aspect: float = texture_size.x / texture_size.y

	var width: float = LOGO_BASE_WIDTH * _Responsive.contain_fit(screen, BASE_CANVAS)
	var height: float = width / aspect

	logo.size = Vector2(width, height)
	logo.position = (screen - logo.size) / 2.0
	logo.pivot_offset = logo.size / 2.0

# ------------------------------------------------------------------------------

func _animate() -> void:
	# Opaque from the very first frame: the boot splash of the platform has ALREADY
	# been showing this logo, at this size and place, while the engine was coming
	# up. Fading it in again would blink the handoff.
	logo.modulate.a = 1.0

	await Wait.forSomeTime(self, LOGO_HOLD).timeout

	_electrify()
	Animate.to(logo, {
		propertyPath = 'modulate:a',
		toValue = 0.0,
		duration = ELECTRIC_LEAD,
		easing = Tween.EASE_IN
	})

	await Wait.forSomeTime(self, ELECTRIC_LEAD).timeout
	_exit()

# ------------------------------------------------------------------------------

func _electrify() -> void:
	var tween := create_tween()
	tween.tween_method(_set_electric_intensity, 0.0, 1.0, ELECTRIC_LEAD) \
		.set_ease(Tween.EASE_IN)

func _set_electric_intensity(value: float) -> void:
	logo.material.set_shader_parameter('intensity', value)
	logo.scale = Vector2.ONE * (1.0 + value * LOGO_GROW)

# ------------------------------------------------------------------------------

func _exit() -> void:
	splashFinished.emit()
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
