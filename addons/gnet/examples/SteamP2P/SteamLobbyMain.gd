# SteamLobbyMain.gd
extends Control

@onready var host_button = $VBoxContainer/HBoxButtons/HostButton
@onready var join_button = $VBoxContainer/HBoxButtons/JoinButton
@onready var disconnect_button = $VBoxContainer/HBoxButtons/DisconnectButton
@onready var refresh_button = $VBoxContainer/HBoxButtons/RefreshButton
@onready var status_label = $VBoxContainer/StatusLabel
@onready var players_list = $VBoxContainer/PlayersList
@onready var lobbies_list = $VBoxContainer/LobbiesList

var connected_peers = []
var current_lobby_id = 0
var is_host = false
var available_lobbies = []

func _ready():
	# Set up button connections
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	
	# Configure NetCore to use Steam
	NetCore.use_adapter("steam")
	NetCore.set_version("1.0.0")
	NetCore.set_mode("listen_server")  # Default mode for hosting
	
	# Set up NetCore signals
	NetCore.peer_connected.connect(_on_peer_connected)
	NetCore.peer_disconnected.connect(_on_peer_disconnected)
	NetCore.session_started.connect(_on_session_started)
	NetCore.session_ended.connect(_on_session_ended)
	NetCore.gnet_error.connect(_on_gnet_error)
	
	# Set up MessageBus for player info
	MessageBus.register_message("player_info", MessageBus.CH_RELIABLE_ORDERED)
	MessageBus.message.connect(_on_message_received)
	
	# Set up Matchmaking signals if available
	if Matchmaking.is_available():
		var backend = Matchmaking._backend
		if backend:
			backend.lobby_created.connect(_on_lobby_created)
			backend.lobby_joined.connect(_on_lobby_joined)
			backend.lobby_list_received.connect(_on_lobby_list_received)
	
	_update_status("Ready - Steam P2P Mode")
	_update_players_list()
	_update_lobbies_list()
	
	# Auto-refresh lobbies on start
	_refresh_lobbies()

# Button handlers
func _on_host_pressed():
	if not Matchmaking.is_available():
		_update_status("Error: Steam matchmaking not available")
		return
	
	_update_status("Creating Steam lobby...")
	host_button.disabled = true
	
	# Create lobby with metadata
	var lobby_opts = {
		"max_members": 4,
		"lobby_type": 1  # Public lobby
	}
	
	is_host = true
	Matchmaking.create(lobby_opts)

func _on_join_pressed():
	var selected_lobby = _get_selected_lobby()
	if not selected_lobby:
		_update_status("Please select a lobby first")
		return
	
	if selected_lobby.slots_free <= 0:
		_update_status("Selected lobby is full")
		return
	
	_update_status("Joining lobby: %s..." % selected_lobby.name)
	join_button.disabled = true
	
	Matchmaking.join(selected_lobby.id)

func _on_refresh_pressed():
	_refresh_lobbies()

func _on_disconnect_pressed():
	_disconnect_from_session()

func _refresh_lobbies():
	if not Matchmaking.is_available():
		_update_status("Error: Steam matchmaking not available")
		return
	
	_update_status("Searching for lobbies...")
	refresh_button.disabled = true
	
	# Search for available lobbies
	var filters = {
		"version": "1.0.0"
	}
	Matchmaking.list(filters)

func _disconnect_from_session():
	NetCore.disconnect_from_host()
	Matchmaking.leave()
	current_lobby_id = 0
	is_host = false
	connected_peers.clear()
	_update_players_list()
	_update_status("Disconnected")
	host_button.disabled = false
	join_button.disabled = false
	refresh_button.disabled = false

# Lobby callbacks
func _on_lobby_created(lobby_id):
	current_lobby_id = lobby_id
	_update_status("Lobby created! ID: %d" % lobby_id)
	
	# Set lobby metadata
	var metadata = {
		"version": "1.0.0",
		"game_mode": "multiplayer",
		"name": "Player's Lobby",
		"max_members": "4"
	}
	Matchmaking.update_metadata(metadata)
	
	# Start hosting the network session
	var host_opts = {
		"max_peers": 3  # 4 total including host
	}
	NetCore.host(host_opts)

func _on_lobby_joined(lobby_id):
	current_lobby_id = lobby_id
	_update_status("Joined lobby! ID: %d" % lobby_id)
	
	# Get the lobby owner to connect to
	var backend = Matchmaking._backend
	if backend:
		var host_steam_id = backend.get_lobby_owner(lobby_id)
		if host_steam_id:
			NetCore.set_mode("client")
			NetCore.connect_to_host(host_steam_id)
		else:
			_update_status("Error: Could not get lobby host")

func _on_lobby_list_received(lobbies):
	refresh_button.disabled = false
	available_lobbies = lobbies
	
	_update_status("Found %d lobbies" % lobbies.size())
	_update_lobbies_list()

# Network session callbacks
func _on_session_started(ctx: Dictionary):
	_update_status("Connected! Mode: %s, Adapter: %s" % [ctx.mode, ctx.adapter])
	host_button.disabled = true
	join_button.disabled = true
	refresh_button.disabled = true
	disconnect_button.disabled = false
	
	# Add ourselves to the players list
	_update_players_list()

func _on_session_ended(ctx: Dictionary):
	_update_status("Session ended")
	_disconnect_from_session()

func _on_peer_connected(peer_id: int):
	connected_peers.append(peer_id)
	_update_players_list()
	_update_status("Player connected: %d" % peer_id)
	
	# Send our player info to the new peer
	var player_info = {
		"name": "Player_%d" % get_tree().get_multiplayer().get_unique_id(),
		"steam_id": get_tree().get_multiplayer().get_unique_id()
	}
	MessageBus.send("player_info", player_info, peer_id)

func _on_peer_disconnected(peer_id: int):
	connected_peers.erase(peer_id)
	_update_players_list()
	_update_status("Player disconnected: %d" % peer_id)
	
	# If host disconnects, leave the session
	if peer_id == 1 and not is_host:
		_disconnect_from_session()

func _on_gnet_error(code: String, details: String):
	_update_status("Error [%s]: %s" % [code, details])
	host_button.disabled = false
	join_button.disabled = false
	refresh_button.disabled = false
	disconnect_button.disabled = true

func _on_message_received(type: String, from_peer: int, payload: Dictionary):
	match type:
		"player_info":
			_update_status("Received player info from %d: %s" % [from_peer, payload.name])

# Lobby selection
func _get_selected_lobby():
	"""Get the currently selected lobby from the UI (simple implementation)."""
	# For now, we'll use a simple selection based on clicking
	# In a more advanced implementation, you'd use ItemList or Tree nodes
	if available_lobbies.size() > 0:
		# This is a placeholder - you'll want to implement proper selection
		# For now, let's use the first lobby as default
		return available_lobbies[0] if available_lobbies.size() > 0 else null
	return null

func _on_lobby_selected(lobby_index: int):
	"""Called when user selects a lobby from the list."""
	if lobby_index >= 0 and lobby_index < available_lobbies.size():
		var lobby = available_lobbies[lobby_index]
		_update_status("Selected: %s (%d/%d players)" % [lobby.name, lobby.member_count, lobby.max_members])

# UI Updates
func _update_status(text: String):
	status_label.text = text
	print("Steam Lobby: " + text)

func _update_players_list():
	var mp = get_tree().get_multiplayer()
	
	if mp.multiplayer_peer == null:
		players_list.text = "Not connected"
		return
	
	var text = "Players in Session:\n"
	var my_id = mp.get_unique_id()
	
	# Show ourselves
	if is_host:
		text += "- You (Host) - ID: %d\n" % my_id
	else:
		text += "- You (Client) - ID: %d\n" % my_id
	
	# Show connected peers
	for peer_id in connected_peers:
		if peer_id == 1 and not is_host:
			text += "- Host - ID: %d\n" % peer_id
		else:
			text += "- Player - ID: %d\n" % peer_id
	
	# Show lobby info if available
	if current_lobby_id > 0:
		text += "\nLobby ID: %d" % current_lobby_id
	
	players_list.text = text

func _update_lobbies_list():
	"""Update the lobbies list display."""
	if available_lobbies.size() == 0:
		lobbies_list.text = "No lobbies found. Click 'Refresh' to search."
		return
	
	var text = "Available Lobbies:\n"
	for i in range(available_lobbies.size()):
		var lobby = available_lobbies[i]
		var status_text = ""
		
		if lobby.slots_free > 0:
			status_text = "JOIN"
		else:
			status_text = "FULL"
		
		text += "%d. %s (%d/%d) [%s]\n" % [
			i + 1,
			lobby.name if lobby.name != "" else "Unnamed Lobby",
			lobby.member_count,
			lobby.max_members,
			status_text
		]
		
		# Add game mode if available
		if lobby.game_mode != "":
			text += "   Mode: %s\n" % lobby.game_mode
	
	text += "\nClick a lobby number to select, then click 'Join'"
	lobbies_list.text = text

# Simple lobby selection via input
func _input(event):
	if event is InputEventKey and event.pressed:
		# Allow selecting lobbies by number keys
		var key_code = event.keycode
		if key_code >= KEY_1 and key_code <= KEY_9:
			var lobby_index = key_code - KEY_1
			if lobby_index < available_lobbies.size():
				_on_lobby_selected(lobby_index)
