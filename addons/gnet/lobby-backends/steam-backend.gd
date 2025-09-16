extends LobbyBackend
"""
Steam lobby backend implementation.

Implements create/list/join using GodotSteam's Lobby APIs. It also
writes/reads metadata like protocol version, capacity, map, and mode.
"""

signal lobby_created(lobby_id)
signal lobby_joined(lobby_id)
signal lobby_list_received(lobbies)
signal lobby_data_updated()

var current_lobby_id := 0
var _steam = null
var _pending_lobby_list := []

func _init():
	"""Initialize Steam singleton if available."""
	if Engine.has_singleton("GodotSteam"):
		_steam = Engine.get_singleton("GodotSteam")
		_connect_steam_signals()
	else:
		push_error("GodotSteam singleton not available")

func _connect_steam_signals():
	"""Connect to Steam lobby signals."""
	if _steam:
		_steam.lobby_created.connect(_on_lobby_created)
		_steam.lobby_joined.connect(_on_lobby_joined)
		_steam.lobby_match_list.connect(_on_lobby_list_received)

func create(opts := {}):
	"""Create a Steam lobby and return its lobby_id."""
	if not _steam:
		push_error("Steam not available")
		return 0
	
	var lobby_type = opts.get("lobby_type", _steam.LOBBY_TYPE_PUBLIC)
	var max_members = opts.get("max_members", 4)
	
	# Create the lobby
	_steam.create_lobby(lobby_type, max_members)
	
	# We'll get the actual lobby_id in the callback
	return 0

func list(filters := {}):
	"""Return an array of { id, slots_free, metadata, ... } for available lobbies."""
	if not _steam:
		return []
	
	_pending_lobby_list.clear()
	
	# Add distance filter if specified
	var distance_filter = filters.get("distance", _steam.LOBBY_DISTANCE_FILTER_DEFAULT)
	_steam.add_request_lobby_list_distance_filter(distance_filter)
	
	# Add string filters if specified
	if filters.has("version"):
		_steam.add_request_lobby_list_string_filter("version", str(filters.version), _steam.LOBBY_COMPARISON_EQUAL)
	
	if filters.has("game_mode"):
		_steam.add_request_lobby_list_string_filter("game_mode", str(filters.game_mode), _steam.LOBBY_COMPARISON_EQUAL)
	
	# Request the lobby list
	_steam.request_lobby_list()
	
	return _pending_lobby_list

func join(lobby_id):
	"""
	Join a Steam lobby by ID and return the host SteamID
	so the Steam adapter can connect to it.
	"""
	if not _steam:
		return 0
	
	current_lobby_id = lobby_id
	_steam.join_lobby(lobby_id)
	
	# We'll return the host SteamID in the callback
	return 0

func leave():
	"""Leave the current Steam lobby if any."""
	if not _steam or current_lobby_id == 0:
		return
	
	_steam.leave_lobby(current_lobby_id)
	current_lobby_id = 0

func update_metadata(meta: Dictionary):
	"""Set/overwrite metadata for the current Steam lobby."""
	if not _steam or current_lobby_id == 0:
		return
	
	for key in meta.keys():
		_steam.set_lobby_data(current_lobby_id, str(key), str(meta[key]))

func get_lobby_owner(lobby_id):
	"""Get the owner (host) SteamID of a lobby."""
	if not _steam:
		return 0
	return _steam.get_lobby_owner(lobby_id)

func get_lobby_member_count(lobby_id):
	"""Get the number of members in a lobby."""
	if not _steam:
		return 0
	return _steam.get_num_lobby_members(lobby_id)

func get_lobby_data(lobby_id, key: String):
	"""Get metadata value from a lobby."""
	if not _steam:
		return ""
	return _steam.get_lobby_data(lobby_id, key)

# Steam callback handlers
func _on_lobby_created(connect: int, lobby_id: int):
	"""Called when lobby creation completes."""
	if connect == 1:  # Success
		current_lobby_id = lobby_id
		emit_signal("lobby_created", lobby_id)
	else:
		push_error("Failed to create lobby")

func _on_lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int):
	"""Called when joining a lobby completes."""
	if response == 1:  # Success
		current_lobby_id = lobby_id
		emit_signal("lobby_joined", lobby_id)
	else:
		push_error("Failed to join lobby: " + str(response))

func _on_lobby_list_received(lobbies: Array):
	"""Called when lobby list request completes."""
	_pending_lobby_list.clear()
	
	for lobby_id in lobbies:
		var lobby_info = {
			"id": lobby_id,
			"owner": get_lobby_owner(lobby_id),
			"member_count": get_lobby_member_count(lobby_id),
			"max_members": int(get_lobby_data(lobby_id, "max_members")),
			"version": get_lobby_data(lobby_id, "version"),
			"game_mode": get_lobby_data(lobby_id, "game_mode"),
			"name": get_lobby_data(lobby_id, "name")
		}
		lobby_info["slots_free"] = lobby_info.max_members - lobby_info.member_count
		_pending_lobby_list.append(lobby_info)
	
	emit_signal("lobby_list_received", _pending_lobby_list)
