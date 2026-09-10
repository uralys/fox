class_name FoxPopup
extends Control

# ==============================================================================
# FoxPopup — base class for popups / overlays (Control-rooted, added under
# $/root/app/popups rather than being the router's currentScene).
#
# Same contract as FoxScreen: override `_onViewportResized()` and the popup
# refreshes on window resize automatically. Wiring is delegated to ViewportResize
# (single source of truth, shared with FoxScreen) and done in _enter_tree /
# _exit_tree so subclasses keep their own _ready without calling super().
# A subclass that overrides _exit_tree must call `super._exit_tree()`.
# ==============================================================================

func _enter_tree() -> void:
	ViewportResize.attach(self, _onViewportResized)

func _exit_tree() -> void:
	ViewportResize.detach(self, _onViewportResized)

func _onViewportResized() -> void:
	pass
