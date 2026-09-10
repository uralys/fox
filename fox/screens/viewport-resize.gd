class_name ViewportResize

# ==============================================================================
# ViewportResize — shared wiring for "refresh on window resize".
#
# Single source of truth used by the Fox base nodes (FoxScreen / FoxPopup): they
# delegate here so the connect/disconnect logic lives in exactly one place,
# regardless of the node type (Node2D screen vs Control popup).
#
# A node opts in simply by defining `_onViewportResized()` and extending one of
# the Fox bases — no per-screen boilerplate, no router glue.
# ==============================================================================

static func attach(node: Node, handler: Callable) -> void:
	var vp := node.get_viewport()
	if vp != null and not vp.size_changed.is_connected(handler):
		vp.size_changed.connect(handler)

static func detach(node: Node, handler: Callable) -> void:
	var vp := node.get_viewport()
	if vp != null and vp.size_changed.is_connected(handler):
		vp.size_changed.disconnect(handler)
