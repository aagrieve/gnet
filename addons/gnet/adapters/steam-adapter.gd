extends GNetAdapter
"""
Steam adapter using SteamMultiplayerPeer (requires GodotSteam).
"""

signal gnet_error(code, details)

var _peer : SteamMultiplayerPeer = null

func _init():
	name = "steam"

func configure(config := {}) -> void:
	"""Verify that GodotSteam/SteamMultiplayerPeer is available."""
	var has_peer_class := ClassDB.class_exists("SteamMultiplayerPeer")
	var has_singleton := Engine.has_singleton("GodotSteam")
	if not has_peer_class:
		emit_signal("gnet_error", "STEAM_MISSING", "SteamMultiplayerPeer not found (is GodotSteam installed?)")

func host(opts := {}):
	"""Create a SteamMultiplayerPeer in host mode and return it."""
	_peer = SteamMultiplayerPeer.new()
	var ok := _peer.create_host(0) # TODO: pass channel config or relay flags if needed
	if ok != OK:
		emit_signal("gnet_error", "HOST", "Steam host create failed: %s" % ok)
		return null
	return _peer

func connect_to(target):
	"""
	Connect as a Steam client to the given target (host SteamID or lobby-resolved ID).
	Returns the connected MultiplayerPeer or null on error.
	"""
	_peer = SteamMultiplayerPeer.new()
	var ok := _peer.create_client(target)
	if ok != OK:
		emit_signal("gnet_error", "CONNECT", "Steam client connect failed (target=%s): %s" % [str(target), ok])
		return null
	return _peer

func close() -> void:
	"""Close the Steam peer if active."""
	if _peer:
		_peer.close()
		_peer = null

func poll(delta: float) -> void:
	"""Pump Steam callbacks if your GodotSteam setup requires manual servicing."""
	pass
