extends Node
class_name Lobby
"""
Lobby façade.

Delegates lobby operations to a backend (Steam). Keeps your game code
decoupled from any one matchmaking provider.
"""

var _backend = null

func _ready():
	"""Create the default (Steam) lobby backend on startup."""
	_backend = load("res://addons/dualnet/lobby_backends/steam_backend.gd").new()

func create(opts := {}):
	"""Create a lobby with options like capacity, visibility, and metadata."""
	return _backend.create(opts)

func list(filters := {}):
	"""Return a list of lobbies filtered by criteria (e.g., protocol/version)."""
	return _backend.list(filters)

func join(lobby_id):
	"""Join a lobby by ID and return the resolved target for the adapter (e.g., host SteamID)."""
	return _backend.join(lobby_id)

func leave():
	"""Leave the current lobby if any."""
	return _backend.leave()

func update_metadata(meta:Dictionary):
	"""Update lobby metadata (e.g., slots, map, protocol) after creation."""
	return _backend.update_metadata(meta)
