# ------------------------------------------------------------------------------

extends RefCounted

# ------------------------------------------------------------------------------

class_name FoxResponsive

# ------------------------------------------------------------------------------
#
# FoxResponsive — shared helpers for the desktop / compact (handheld) UI split.
#
# Single source of truth for how a fixed-size UI adapts to the viewport, so every
# screen of every fox game reuses the same rule:
#
#   - Compact (handheld, e.g. Steam Deck — physical window width < `min_desktop_width`,
#     or `force_compact` forced by the caller):
#       the UI uses the full contain-fit so a fixed-size chassis fills the small
#       screen, and fixed-size UI elements are enlarged (`ui_scale`).
#   - Desktop (physical window width >= `min_desktop_width`):
#       the contain-fit is capped at `desktop_max_scale`, keeping a windowed
#       footprint centered on large monitors instead of filling the whole screen,
#       and fixed-size UI elements stay native (1.0).
#
# WHY statics take `min_desktop_width` / `force_compact` as ARGUMENTS
#   GDScript static functions do NOT dispatch virtually, so this base can never
#   read a game-specific token (DesignTokens.Breakpoints) or autoload
#   (SteamManager.is_steam_deck()) on its own. Each game injects them at the call
#   site: the width threshold as `min_desktop_width`, and its "this is a handheld" hook
#   (e.g. SteamManager.is_steam_deck()) as `force_compact`. This base references
#   NEITHER DesignTokens NOR SteamManager.
#
# IMPORTANT — logical vs physical size
#   Games run in stretch mode `canvas_items` + aspect `expand`, so
#   `get_viewport_rect().size` is the LOGICAL canvas size (~1920 wide) on every
#   device, including a handheld (a Steam Deck is physically 1280×800). The
#   compact / desktop decision must therefore use the PHYSICAL window size
#   (`screen_size`, from DisplayServer.window_get_size()), while the fit math
#   keeps using the logical viewport size (the scale is applied to a node living
#   in the logical canvas). Never compare the logical viewport width to the
#   min_desktop_width — a handheld would be misclassified as desktop.
#
# Function mapping (union of the two games consolidated here)
#   sylvestrine src/ui/responsive.gd  faraday src/ui/responsive.gd  -> FoxResponsive
#   is_desktop(screen_size)           is_desktop(screen_size)          is_desktop(screen_size, min_desktop_width, force_compact)
#   screen_size()                     screen_size()                    screen_size()
#   ui_scale(compact_scale, ...)      ui_scale(compact_scale, ...)     ui_scale(compact_scale, min_desktop_width, ...)
#   contain_fit(vp, base)             contain_fit(vp, base)            contain_fit(vp, base)
#   fit_scale(vp, base, cap, phys)    fit_scale(vp, base, cap, phys,   fit_scale(vp, base, min_desktop_width, cap,
#                                                compact_margin_px)               force_compact, phys, compact_margin_px)
#   —                                 apply_cursor_visibility()        apply_cursor_visibility(hide_cursor)
#
# The two games keep their own `class_name Responsive` thin wrapper that binds
# DesignTokens.Breakpoints.DESKTOP_MIN_WIDTH and SteamManager.is_steam_deck() and
# forwards to these statics; FoxResponsive itself stays engine-agnostic.
#
# ------------------------------------------------------------------------------

# A handheld (`force_compact`, e.g. Steam-reported Steam Deck) is always compact,
# whatever its physical width (it may be docked to an external monitor): it is a
# gamepad-driven device. Off a handheld we fall back to the width threshold on the
# PHYSICAL window size.
static func is_desktop(screen_size: Vector2, min_desktop_width: float, force_compact: bool = false) -> bool:
  if force_compact:
    return false
  return screen_size.x >= min_desktop_width

# ------------------------------------------------------------------------------

# Physical window size in pixels — drives the compact / desktop decision.
static func screen_size() -> Vector2:
  return Vector2(DisplayServer.window_get_size())

# ------------------------------------------------------------------------------

# Multiplier for fixed-size UI (buttons, panels…): enlarged on compact screens
# (handheld) where native sizes read too small, native (1.0) on desktop.
# `physical_size` defaults to the current window.
static func ui_scale(
  compact_scale: float,
  min_desktop_width: float,
  force_compact: bool = false,
  physical_size: Vector2 = Vector2.ZERO
) -> float:
  var physical := physical_size if physical_size != Vector2.ZERO else screen_size()
  return 1.0 if is_desktop(physical, min_desktop_width, force_compact) else compact_scale

# ------------------------------------------------------------------------------

# Uniform "contain" scale: grows `base_size` to fill `viewport_size` while
# keeping its aspect ratio (no distortion).
static func contain_fit(viewport_size: Vector2, base_size: Vector2) -> float:
  if base_size.x <= 0.0 or base_size.y <= 0.0:
    return 1.0
  return min(viewport_size.x / base_size.x, viewport_size.y / base_size.y)

# ------------------------------------------------------------------------------

# Fit scale for a fixed-size chassis: fills compact screens, capped on desktop.
# `viewport_size` is the LOGICAL viewport (for the fit math); the desktop cap is
# decided on the PHYSICAL window size (defaults to the current window).
# `compact_margin_px` reserves that many PHYSICAL pixels on ALL FOUR edges (top,
# bottom, left, right) on compact screens (handheld) so the chassis never touches
# the screen border; it is converted to logical units per axis (the fit math runs
# on the logical canvas, which may scale differently on X/Y) and ignored on
# desktop, where `desktop_max_scale` already keeps a windowed footprint.
static func fit_scale(
  viewport_size: Vector2,
  base_size: Vector2,
  min_desktop_width: float,
  desktop_max_scale: float = 1.0,
  force_compact: bool = false,
  physical_size: Vector2 = Vector2.ZERO,
  compact_margin_px: float = 0.0
) -> float:
  var physical := physical_size if physical_size != Vector2.ZERO else screen_size()
  if is_desktop(physical, min_desktop_width, force_compact):
    return min(contain_fit(viewport_size, base_size), desktop_max_scale)

  var fit_size := viewport_size
  if compact_margin_px > 0.0:
    # Physical px → logical units per axis (the chassis lives in the logical
    # canvas). Reserve the same physical margin on every edge.
    if physical.y > 0.0:
      fit_size.y = max(0.0, viewport_size.y - 2.0 * compact_margin_px * (viewport_size.y / physical.y))
    if physical.x > 0.0:
      fit_size.x = max(0.0, viewport_size.x - 2.0 * compact_margin_px * (viewport_size.x / physical.x))
  return contain_fit(fit_size, base_size)

# ------------------------------------------------------------------------------

# Keeps the mouse ENABLED everywhere (the on-screen UI — e.g. a BACK chevron — is
# pointer-driven, and on a handheld the trackpad acts as that pointer), while
# hiding only the visible cursor when `hide_cursor` is set (a stray pointer is
# noise on a gamepad-driven handheld). The caller decides `hide_cursor` (e.g.
# SteamManager.is_steam_deck()) — this base does not read any autoload.
#
# We hide it with a transparent custom cursor rather than MOUSE_MODE_HIDDEN: on
# Wayland (a Deck falls back to it when launched over SSH) MOUSE_MODE_HIDDEN can
# swallow clicks, which reads as "the mouse is disabled". On desktop the cursor
# stays visible regardless of window size — a small window is still mouse-driven,
# so callers must NOT key `hide_cursor` off the compact / desktop width split.
static var _transparent_cursor: ImageTexture = null

static func apply_cursor_visibility(hide_cursor: bool) -> void:
  Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
  if hide_cursor:
    Input.set_custom_mouse_cursor(_get_transparent_cursor())
  else:
    Input.set_custom_mouse_cursor(null)

static func _get_transparent_cursor() -> ImageTexture:
  if _transparent_cursor == null:
    var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
    img.set_pixel(0, 0, Color(0, 0, 0, 0))
    _transparent_cursor = ImageTexture.create_from_image(img)
  return _transparent_cursor
