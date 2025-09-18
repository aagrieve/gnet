extends GNetAdapter
"""
Steam adapter using SteamMultiplayerPeer (requires GodotSteam).
"""

signal gnet_error(code, details)

var _peer : SteamMultiplayerPeer = null
var _steam_initialized := false
var _steam_ready := false
var _current_lobby_id := 0

func _init():
	name = "steam"

func configure(config := {}) -> void:
	"""Verify that GodotSteam/SteamMultiplayerPeer is available and initialize Steam."""
	var has_peer_class := ClassDB.class_exists("SteamMultiplayerPeer")
	var has_singleton := Engine.has_singleton("Steam")
	
	if not has_peer_class:
		emit_signal("gnet_error", "STEAM_MISSING", "SteamMultiplayerPeer not found (is GodotSteam installed?)")
		return
	
	if not has_singleton:
		emit_signal("gnet_error", "STEAM_MISSING", "Steam singleton not found")
		return
	
	# Initialize Steam API
	if not _steam_initialized:
		_initialize_steam()

func _initialize_steam():
	"""Initialize the Steam API."""
	if not Engine.has_singleton("Steam"):
		return
	
	var steam = Engine.get_singleton("Steam")
	print("Initializing Steam API...")
	
	# Connect to the correct Steam connection signal
	if steam.has_signal("steam_server_connected"):
		steam.steam_server_connected.connect(_on_steam_connected)
		print("Connected to steam_server_connected signal")
	else:
		print("steam_server_connected signal not found")
	
	var init_result = steam.steamInit()
	print("Steam init result: ", init_result)
	
	if init_result:
		_steam_initialized = true
		# Check immediately in case we're already connected
		_check_steam_status()
	else:
		print("Failed to initialize Steam API")
		emit_signal("gnet_error", "STEAM_INIT_FAILED", "Failed to initialize Steam API")

func _on_steam_connected():
	"""Called when Steam server connection is established."""
	print("Steam server connected callback received!")
	_steam_ready = true
	_check_steam_status()

func host(opts := {}):
	"""Create a SteamMultiplayerPeer in host mode and return it."""
	
	# Make sure Steam is ready
	if not _steam_ready:
		emit_signal("gnet_error", "STEAM_NOT_READY", "Steam API not ready yet - try again in a moment")
		return null
	
	_peer = SteamMultiplayerPeer.new()
	
	# Connect to the SteamMultiplayerPeer's lobby_created signal
	_peer.lobby_created.connect(_on_lobby_created_for_id)
	
	var max_players = opts.get("max_players", 4)
	
	print("Attempting to create lobby with max_players: ", max_players)
	var ok: Error = _peer.create_lobby(SteamMultiplayerPeer.LOBBY_TYPE_PUBLIC, max_players)
	
	if ok != OK:
		print("create_lobby result: ", ok, " (Error name: ", error_string(ok), ")")
		emit_signal("gnet_error", "HOST", "Steam host create failed: %s (%s)" % [ok, error_string(ok)])
		return null

	print("Lobby created successfully!")
	return _peer

func _on_lobby_created_for_id(result: int, lobby_id: int):
	"""Called when SteamMultiplayerPeer lobby creation completes."""
	if result == 1:  # Success (Steam.Result.RESULT_OK)
		_current_lobby_id = lobby_id
		print("=== LOBBY CREATED ===")
		print("Lobby ID: ", lobby_id)
		print("Share this ID with friends to join!")
		print("====================")
	else:
		print("Lobby creation failed with result: ", result)

func connect_to(target):
	"""
	Connect as a Steam client to the given target (host SteamID or lobby-resolved ID).
	Returns the connected MultiplayerPeer or null on error.
	"""
	_peer = SteamMultiplayerPeer.new()
	var ok: Error = _peer.connect_lobby(target)
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
	if Engine.has_singleton("Steam"):
		var steam = Engine.get_singleton("Steam")
		steam.run_callbacks()

func _check_steam_status():
	"""Check if Steam is ready and set _steam_ready accordingly."""
	var steam = Engine.get_singleton("Steam")
	
	print("=== Checking Steam Status ===")
	print("Steam running: ", steam.isSteamRunning())
	print("Steam logged on: ", steam.loggedOn())
	print("Steam ID: ", steam.getSteamID())
	print("App ID: ", steam.getAppID())
	
	# Consider Steam ready if it's running and we have a valid Steam ID
	if steam.isSteamRunning() and steam.getSteamID() > 0:
		_steam_ready = true
		print("Steam is ready!")
	else:
		print("Steam not ready yet...")
	
	print("============================")
