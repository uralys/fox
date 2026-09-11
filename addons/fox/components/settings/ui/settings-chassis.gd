extends RefCounted

# ==============================================================================
# settings-chassis.gd — the shared frame of the settings family of screens (fox).
#
#   ┌───────────────────────────────────────────────────────────┐
#   │ ◀ BACK              T I T L E                             │ header band
#   │                                                           │
#   │                    ( the band a plate is fitted into )     │
#   │                                                           │
#   │ ● v1.2.0                        🌐 Français · Privacy     │ footer band
#   └───────────────────────────────────────────────────────────┘
#
# Settings and Languages are two screens of the SAME family — faraday builds them
# both on its level-select chassis — so the background, the header with its BACK
# door and centred title, and the footer bar are built once here and worn by both.
# Each screen then fits its own plate into `band`.
#
# The two bands span the VIEWPORT; only the plate is fitted (and sized, never
# scaled — see settings-plate.gd).
# ==============================================================================

const _SettingsText := preload('res://addons/fox/components/settings/settings-text.gd')
const _TextLink := preload('res://addons/fox/components/settings/ui/settings-text-link.gd')

const HEADER_HEIGHT := 78.0
const FOOTER_HEIGHT := 56.0
const EDGE_MARGIN := 40.0
const TITLE_TRACKING_EM := 0.32

var background: ColorRect = null
var header: Control = null
var back_link: Control = null
var footer_bar: Control = null

# The rect left between the two bands, minus the board margins: where a plate goes.
var band: Rect2 = Rect2()

func build(
	host: Node, theme_data: SettingsThemeData, title: String,
	back_text: String, on_back: Callable
) -> void:
	var screen: Vector2 = host.get_viewport_rect().size

	background = ColorRect.new()
	background.name = 'background'
	background.color = theme_data.background
	background.size = screen
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(background)

	_build_header(host, theme_data, screen, title, back_text, on_back)
	_build_footer_bar(host, theme_data, screen)

	var top: float = HEADER_HEIGHT + theme_data.board_margin_y
	var bottom: float = screen.y - FOOTER_HEIGHT - theme_data.board_margin_y
	band = Rect2(
		Vector2(theme_data.board_margin_x, top),
		Vector2(
			maxf(0.0, screen.x - theme_data.board_margin_x * 2.0),
			maxf(0.0, bottom - top)
		)
	)

func _build_header(
	host: Node, theme_data: SettingsThemeData, screen: Vector2,
	title: String, back_text: String, on_back: Callable
) -> void:
	header = Control.new()
	header.name = 'header'
	header.size = Vector2(screen.x, HEADER_HEIGHT)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(header)

	back_link = _TextLink.new()
	back_link.theme_data = theme_data
	back_link.text = '◀  ' + back_text
	back_link.position = Vector2(EDGE_MARGIN, (HEADER_HEIGHT - theme_data.footer_size) * 0.5)
	back_link.activated.connect(on_back)
	header.add_child(back_link)

	var title_node := Control.new()
	title_node.name = 'title'
	title_node.size = Vector2(screen.x, HEADER_HEIGHT)
	title_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_node.draw.connect(func() -> void:
		var font: Font = theme_data.font_title
		if font == null:
			font = ThemeDB.fallback_font
		var width: float = _SettingsText.spaced_width(
			font, title, theme_data.title_size, TITLE_TRACKING_EM
		)
		_SettingsText.draw_spaced(
			title_node, font,
			Vector2(
				(screen.x - width) * 0.5,
				HEADER_HEIGHT * 0.5 + theme_data.title_size * 0.36
			),
			title, theme_data.title_size, theme_data.accent, TITLE_TRACKING_EM
		)
		title_node.draw_line(
			Vector2(0, HEADER_HEIGHT - 1), Vector2(screen.x, HEADER_HEIGHT - 1),
			theme_data.accent_at(0.20), 1.0
		)
	)
	header.add_child(title_node)

func _build_footer_bar(host: Node, theme_data: SettingsThemeData, screen: Vector2) -> void:
	footer_bar = Control.new()
	footer_bar.name = 'footer_bar'
	footer_bar.size = Vector2(screen.x, FOOTER_HEIGHT)
	footer_bar.position = Vector2(0, screen.y - FOOTER_HEIGHT)
	footer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_bar.draw.connect(func() -> void:
		footer_bar.draw_line(
			Vector2(0, 0), Vector2(screen.x, 0), theme_data.accent_at(0.20), 1.0
		)
	)
	host.add_child(footer_bar)
