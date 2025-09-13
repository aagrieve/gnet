extends RefCounted
class_name GNetAdapter
"""
Abstract transport adapter for gNet.

Concrete adapters (Steam, ENet) must implement host/connect/close/poll and
emit `error(code, details)` when failures occur.
"""

signal error(code, details)

var name : String

func configure(config := {}) -> void:
	"""Optional adapter initialization hook (SDK checks, config)."""
	pass

func host(opts := {}):
	"""Create and return a MultiplayerPeer configured for hosting, or null on failure."""
	return null

func connect_to(target):
	"""
	Create and return a MultiplayerPeer configured for connecting, or null on failure.

	`target` is adapter-specific (e.g., SteamID or 'address:port' for ENet).
	Can be used to connect to peers or dedicated servers.
	"""
	return null

func close() -> void:
	"""Close and clean up any active peer/resources for this adapter."""
	pass

func poll(delta: float) -> void:
	"""Per-frame pump to service SDK callbacks or connection maintenance."""
	pass
