extends DualNetAdapter
"""
Steam transport adapter using SteamMultiplayerPeer.

Relies on GodotSteam being present and initialized. Creates a Steam-based
MultiplayerPeer to host (listen-server) or connect to a host SteamID.
"""

var name := "steam"
var _peer := null

func init(config := {}):
	"""Verify GodotSteam is available and capture any adapter config."""
	# Example guard (adjust to your GodotSteam setup):
	# if not Engine.has_singleton("GodotSteam"):
	# push_error("GodotSteam not found; install the GDExtension to use the Steam adapter.")
	pass

func host(opts := {}):
	"""Create a SteamMultiplayerPeer in host mode and return it."""
	_peer = SteamMultiplayerPeer.new()
	var ok := _peer.create_host(0) # TODO: channel config or relay flags
	if ok != OK:
		push_error("Steam host create failed: %s" % ok)
	return _peer

func connect(target):
	"""
	Connect as a Steam client to the given 'target' (usually a host SteamID
	resolved from the Lobby backend). Returns the connected peer.
	"""
	_peer = SteamMultiplayerPeer.new()
	var ok := _peer.create_client(target)
	if ok != OK:
		push_error("Steam client connect failed: %s" % ok)
	return _peer

func close():
	"""Close the Steam peer if active."""
	if _peer:
		_peer.close()

func poll(delta: float) -> void:
	"""Pump Steam callbacks if your GodotSteam setup requires manual servicing."""
	pass
