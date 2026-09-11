class_name FoxScreen
extends Node2D

# ==============================================================================
# FoxScreen — base class for game screens (Node2D-rooted router scenes).
#
# Self-wires the viewport `size_changed` signal to `_onViewportResized` so every
# screen refreshes its responsive layout on window resize, with zero per-screen
# boilerplate and no router glue. Override `_onViewportResized()` to rebuild.
#
# Wiring lives in _enter_tree / _exit_tree (not _ready) so subclasses are free to
# define their own _ready without having to call super(). A subclass that does
# override _exit_tree must call `super._exit_tree()`.
#
# Resize decision helpers (compact / desktop breakpoint) live in `Responsive`.
# ==============================================================================

func _enter_tree() -> void:
	ViewportResize.attach(self, _onViewportResized)

func _exit_tree() -> void:
	ViewportResize.detach(self, _onViewportResized)

func _onViewportResized() -> void:
	pass
