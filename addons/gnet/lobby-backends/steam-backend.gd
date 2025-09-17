extends LobbyBackend
"""
Steam lobby backend using the Steam singleton from pre-compiled bundle.
"""

signal lobby_created(lobby_id)
signal lobby_joined(lobby_id)
signal lobby_list_received(lobbies)
signal lobby_data_updated()

var current_lobby_id := 0
var _steam = null
var _pending_lobby_list := []
var _initialization_complete := false

func _init():
	"""Initialize Steam singleton if available."""
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
		print("Steam singleton found, initializing...")
		_initialize_steam()
	else:
		push_error("Steam singleton not available")

func _initialize_steam():
	"""Initialize Steam API."""
	if not _steam:
		return
	
	print("Initializing Steam API...")
	
	# Initialize Steam API first
	var init_result = _steam.steamInit()
	print("Steam init result: ", init_result)
	
	# Use a simple delay instead of get_tree().create_timer()
	await _simple_wait(1.0)
	
	# Now check status
	print("=== Steam Status After Init ===")
	print("Steam running: ", _steam.isSteamRunning())
	
	# Only check these if Steam is running
	if _steam.isSteamRunning():
		print("Steam logged on: ", _steam.loggedOn())
		print("Steam ID: ", _steam.getSteamID())
		print("Current App ID: ", _steam.getAppID())
	else:
		print("Steam not running - cannot check login status")
	print("==============================")
	
	_connect_steam_signals()
	_initialization_complete = true
	print("Steam backend initialization complete")

func _simple_wait(seconds: float):
	"""Simple wait function that doesn't require get_tree()."""
	var start_time = Time.get_ticks_msec()
	var wait_ms = seconds * 1000
	
	while Time.get_ticks_msec() - start_time < wait_ms:
		# Just wait - this will block but that's OK for initialization
		pass

func _connect_steam_signals():
	"""Connect to Steam lobby signals."""
	if _steam:
		print("=== Steam Signal Debug ===")
		
		# Connect to standard GodotSteam signals
		if _steam.has_signal("lobby_created"):
			var result = _steam.lobby_created.connect(_on_lobby_created)
			print("Connected lobby_created signal, result:", result)
		else:
			print("WARNING: lobby_created signal not found")
			
		if _steam.has_signal("lobby_joined"):
			_steam.lobby_joined.connect(_on_lobby_joined)
			print("Connected lobby_joined signal")
		else:
			print("WARNING: lobby_joined signal not found")
			
		if _steam.has_signal("lobby_match_list"):
			_steam.lobby_match_list.connect(_on_lobby_list_received)
			print("Connected lobby_match_list signal")
		else:
			print("WARNING: lobby_match_list signal not found")
			
		if _steam.has_signal("lobby_data_update"):
			_steam.lobby_data_update.connect(_on_lobby_data_update)
			print("Connected lobby_data_update signal")
		else:
			print("WARNING: lobby_data_update signal not found")
		print("========================")


func poll_steam_callbacks():
	"""Process Steam callbacks for lobby operations."""
	if _steam:
		_steam.run_callbacks()

func _on_lobby_data_update(success: int, lobby_id: int, member_id: int):
	"""Called when lobby data is updated."""
	print("Lobby data update callback: success=", success, " lobby_id=", lobby_id, " member_id=", member_id)
	emit_signal("lobby_data_updated")

func create(opts := {}):
	"""Create a Steam lobby"""
	if not _steam:
		push_error("Steam not available")
		return 0
	
	# Check if Steam API is ready before making calls
	if not _steam.isSteamRunning():
		push_error("Steam not running")
		return 0
	
	# Only check login if Steam is running (to avoid the error)
	if not _steam.loggedOn():
		push_error("Not logged into Steam")
		return 0
	
	var lobby_type = opts.get("lobby_type", 1)
	var max_members = opts.get("max_members", 4)
	
	print("Creating lobby with type: ", lobby_type, " max_members: ", max_members)
	print("Signals connected - lobby_created:", _steam.lobby_created.is_connected(_on_lobby_created))
	print("Signals connected - lobby_joined:", _steam.lobby_joined.is_connected(_on_lobby_joined))
	print("Signals connected - lobby_data_update:", _steam.lobby_data_update.is_connected(_on_lobby_data_update))
	
	_steam.createLobby(lobby_type, max_members)
	
	return 0

func list(filters := {}):
	"""Return an array of available lobbies."""
	if not _steam:
		return []
	
	# Check if Steam API is ready
	if not _steam.isSteamRunning():
		push_error("Steam not running")
		return []
	
	if not _steam.loggedOn():
		push_error("Not logged into Steam")
		return []
	
	_pending_lobby_list.clear()
	
	# Add filters if specified
	if filters.has("version"):
		_steam.addRequestLobbyListStringFilter("version", str(filters.version), 0)
	
	if filters.has("game_mode"):
		_steam.addRequestLobbyListStringFilter("game_mode", str(filters.game_mode), 0)
	
	print("Requesting lobby list...")
	_steam.requestLobbyList()
	
	return _pending_lobby_list

func join(lobby_id):
	"""Join a Steam lobby by ID."""
	if not _steam:
		return 0
	
	current_lobby_id = lobby_id
	print("Joining lobby: ", lobby_id)
	_steam.joinLobby(lobby_id)
	
	return 0

func leave():
	"""Leave the current Steam lobby if any."""
	if not _steam or current_lobby_id == 0:
		return
	
	print("Leaving lobby: ", current_lobby_id)
	_steam.leaveLobby(current_lobby_id)
	current_lobby_id = 0

func update_metadata(meta: Dictionary):
	"""Set/overwrite metadata for the current Steam lobby."""
	if not _steam or current_lobby_id == 0:
		return
	
	print("Updating lobby metadata: ", meta)
	for key in meta.keys():
		_steam.setLobbyData(current_lobby_id, str(key), str(meta[key]))

func get_lobby_owner(lobby_id):
	"""Get the owner (host) SteamID of a lobby."""
	if not _steam:
		return 0
	return _steam.getLobbyOwner(lobby_id)

func get_lobby_member_count(lobby_id):
	"""Get the number of members in a lobby."""
	if not _steam:
		return 0
	return _steam.getNumLobbyMembers(lobby_id)

func get_lobby_data(lobby_id, key: String):
	"""Get metadata value from a lobby."""
	if not _steam:
		return ""
	return _steam.getLobbyData(lobby_id, key)

# Steam callback handlers
func _on_lobby_created(connect: int, lobby_id: int):
	"""Called when lobby creation completes."""
	print("Lobby creation callback: connect=", connect, " lobby_id=", lobby_id)
	if connect == 1:  # Success
		current_lobby_id = lobby_id
		emit_signal("lobby_created", lobby_id)
	else:
		push_error("Failed to create lobby")

func _on_lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int):
	"""Called when joining a lobby completes."""
	print("Lobby joined callback: lobby_id=", lobby_id, " response=", response)
	if response == 1:  # Success
		current_lobby_id = lobby_id
		emit_signal("lobby_joined", lobby_id)
	else:
		push_error("Failed to join lobby: " + str(response))

func _on_lobby_list_received(lobbies: Array):
	"""Called when lobby list request completes."""
	print("Lobby list received: ", lobbies.size(), " lobbies")
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
		lobby_info["slots_free"] = max(0, lobby_info.max_members - lobby_info.member_count)
		_pending_lobby_list.append(lobby_info)
		print("Found lobby: ", lobby_info)
	
	emit_signal("lobby_list_received", _pending_lobby_list)
