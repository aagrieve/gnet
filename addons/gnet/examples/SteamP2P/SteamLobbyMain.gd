# SteamLobbyMain.gd
extends Control

@onready var host_button = $VBoxContainer/HBoxButtons/HostButton
@onready var join_button = $VBoxContainer/HBoxButtons/JoinButton
@onready var disconnect_button = $VBoxContainer/HBoxButtons/DisconnectButton
@onready var refresh_button = $VBoxContainer/HBoxButtons/RefreshButton
@onready var status_label = $VBoxContainer/StatusLabel
@onready var players_list = $VBoxContainer/PlayersList
@onready var lobbies_list = $VBoxContainer/LobbiesList
@onready var lobby_id_input = $VBoxContainer/HBoxInputs/LobbyIDInput

var connected_peers = []
var is_host = false

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
	
	_update_status("Ready - Click Host to create lobby")

# Button handlers
func _on_host_pressed():
	_update_status("Creating Steam lobby...")
	host_button.disabled = true
	
	is_host = true
	var host_opts = {
		"max_players": 4
	}
	NetCore.host(host_opts)

func _on_join_pressed():
	var lobby_id_text = lobby_id_input.text
	if lobby_id_text.is_valid_int():
		var lobby_id = lobby_id_text.to_int()
		NetCore.set_mode("client")
		NetCore.connect_to_host(lobby_id)
	else:
		_update_status("Please enter a valid lobby ID")

func _on_refresh_pressed():
	# For now, disable lobby browsing
	_update_status("Lobby browsing not available without Matchmaking system")

func _on_disconnect_pressed():
	_disconnect_from_session()

func _disconnect_from_session():
	NetCore.disconnect_from_host()
	is_host = false
	connected_peers.clear()
	_update_players_list()
	_update_status("Disconnected")
	host_button.disabled = false
	join_button.disabled = false
	refresh_button.disabled = false

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
	is_host = false
	connected_peers.clear()
	_update_players_list()
	
	# Re-enable buttons
	host_button.disabled = false
	join_button.disabled = false
	refresh_button.disabled = false
	disconnect_button.disabled = true

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
	
	players_list.text = text
