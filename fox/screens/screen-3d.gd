class_name FoxScreen3D
extends Node3D

# ==============================================================================
# FoxScreen3D — base class for 3D game screens (Node3D-rooted router scenes).
#
# Same contract as FoxScreen, for screens whose root is a Node3D instead of a
# Node2D: override `_onViewportResized()` and the screen refreshes its responsive
# layout on window resize automatically — zero per-screen boilerplate, no router
# glue (no duck-typing on the router side).
#
# Wiring is delegated to ViewportResize (single source of truth, shared with
# FoxScreen / FoxPopup) and done in _enter_tree / _exit_tree (not _ready) so
# subclasses are free to define their own _ready without calling super().
# A subclass that overrides _exit_tree must call `super._exit_tree()`.
#
# Resize decision helpers (compact / desktop breakpoint) live in `Responsive`.
# ==============================================================================

func _enter_tree() -> void:
	ViewportResize.attach(self, _onViewportResized)

func _exit_tree() -> void:
	ViewportResize.detach(self, _onViewportResized)

func _onViewportResized() -> void:
	pass
