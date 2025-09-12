extends RefCounted
class_name DualNetAdapter
"""
Abstract transport adapter.

All concrete adapters (Steam, ENet) should implement this interface to
normalize hosting, connecting, closing, and per-frame polling.
"""

var name := "base"

func init(config := {}):
	"""Optional adapter initialization hook (SDK checks, config)."""
	pass

func host(opts := {}):
	"""Create and return a MultiplayerPeer configured for hosting."""
	return null

func connect(target):
	"""
	Create and return a MultiplayerPeer configured for connecting.
	'target' is adapter-specific (e.g., SteamID or 'address:port').
	"""
	return null

func close():
	"""Close and clean up any active peer/resources for this adapter."""
	pass

func poll(delta: float) -> void:
	"""Per-frame pump to service SDK callbacks or connection maintenance."""
	pass
