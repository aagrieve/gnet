extends LobbyBackend
"""
Steam lobby backend (skeleton).

Implements create/list/join using GodotSteam's Lobby APIs. It should also
write/read metadata like protocol version, capacity, map, and mode.
"""

var current_lobby_id := 0

func create(opts := {}):
	"""Create a Steam lobby and return its lobby_id."""
	# TODO: call GodotSteam's lobby create and set metadata.
	return 0

func list(filters := {}):
	"""Return an array of { id, slots_free, metadata, ... } for available lobbies."""
	# TODO: use GodotSteam to request lobby list and map results to a simple format.
	return []

func join(lobby_id):
	"""
	Join a Steam lobby by ID and return the host SteamID
	so the Steam adapter can connect to it.
	"""
	current_lobby_id = lobby_id
	# TODO: resolve the lobby owner/host SteamID via GodotSteam.
	return 0

func leave():
	"""Leave the current Steam lobby if any."""
	current_lobby_id = 0
	# TODO: call GodotSteam leave.

func update_metadata(meta:Dictionary):
	"""Set/overwrite metadata for the current Steam lobby."""
	# TODO: write metadata keys via GodotSteam.
	pass
