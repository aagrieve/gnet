# LobbyMain.gd
extends Control

@onready var host_button = $VBoxContainer/HBoxButtons/HostButton
@onready var join_button = $VBoxContainer/HBoxButtons/JoinButton
@onready var disconnect_button = $VBoxContainer/HBoxButtons/DisconnectButton
@onready var start_button = $VBoxContainer/HBoxButtons/StartButton
@onready var ip_input = $VBoxContainer/HBoxInputs/IPInput
@onready var port_input = $VBoxContainer/HBoxInputs/PortLabel
@onready var status_label = $VBoxContainer/StatusLabel
@onready var players_list = $VBoxContainer/PlayersList

var connected_peers = []

func _ready():
	# Set up button connections
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	start_button.pressed.connect(_on_start_pressed)
	
	# Set up NetCore signals
	NetCore.peer_connected.connect(_on_peer_connected)
	NetCore.peer_disconnected.connect(_on_peer_disconnected)
	NetCore.session_started.connect(_on_session_started)
	NetCore.session_ended.connect(_on_session_ended)
	NetCore.gnet_error.connect(_on_gnet_error)
	
	# Set up MessageBus for chat/communication
	MessageBus.register_message("player_info", MessageBus.CH_RELIABLE_ORDERED)
	MessageBus.register_message("chat", MessageBus.CH_RELIABLE_ORDERED)
	MessageBus.register_message("game_start", MessageBus.CH_RELIABLE_ORDERED)
	MessageBus.message.connect(_on_message_received)
	
	# Configure NetCore to use ENet
	NetCore.use_adapter("enet")
	NetCore.set_version("1.0.0")
	
	# Set default values
	ip_input.text = "127.0.0.1"
	port_input.text = "3456"
	_update_status("Ready to host or join")

# Button Presses
# -----------------------------------------------------------------------------
func _on_host_pressed():
	_update_status("Starting host...")
	
	# Set mode and start hosting
	NetCore.set_mode("listen_server")
	
	var port = int(port_input.text)
	var opts = {
		"port": port,
		"max_peers": 8
	}
	
	NetCore.host(opts)

func _on_join_pressed():
	_update_status("Connecting...")
	
	# Set mode to client
	NetCore.set_mode("client")
	
	var target = ip_input.text + ":" + port_input.text
	NetCore.connect_to_host(target)

func _on_disconnect_pressed():
	NetCore.disconnect_from_host()
	
func _on_start_pressed():
	print("Starting game...")
	print("Current peer ID: ", get_tree().get_multiplayer().get_unique_id())
	print("Is server: ", get_tree().get_multiplayer().is_server())
	print("Connected peers: ", connected_peers)
	
	MessageBus.send("game_start", {"starting": true})
	print("Message sent via MessageBus")
	
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://addons/gnet/examples/CapsuleRoom/Game.tscn")

# -----------------------------------------------------------------------------
# end Button Presses

# Lobby Connections
# -----------------------------------------------------------------------------
func _on_peer_connected(peer_id: int):
	connected_peers.append(peer_id)
	_update_players_list()
	_update_status("Peer %d connected" % peer_id)
	
	# Send our player info to the new peer
	var player_info = {
		"name": "Player_%d" % get_tree().get_multiplayer().get_unique_id(),
		"peer_id": get_tree().get_multiplayer().get_unique_id()
	}
	MessageBus.send("player_info", player_info, peer_id)

func _on_peer_disconnected(peer_id: int):
	connected_peers.erase(peer_id)
	_update_players_list()
	_update_status("Peer %d disconnected" % peer_id)

	if peer_id == 1:
		NetCore.disconnect_from_host()

func _on_session_started(ctx: Dictionary):
	_update_status("Session started as %s using %s" % [ctx.mode, ctx.adapter])
	host_button.disabled = true
	join_button.disabled = true

func _on_session_ended(ctx: Dictionary):
	_update_status("Ready to host or join")
	connected_peers.clear()
	_update_players_list()
	host_button.disabled = false
	join_button.disabled = false

func _on_gnet_error(code: String, details: String):
	_update_status("Error [%s]: %s" % [code, details])
	host_button.disabled = false
	join_button.disabled = false

func _on_message_received(type: String, from_peer: int, payload: Dictionary):
	print("Received message type: ", type, " from peer: ", from_peer)
	match type:
		"player_info":
			_update_status("Received player info from peer %d: %s" % [from_peer, payload.name])
		"chat":
			_update_status("Chat from %d: %s" % [from_peer, payload.text])
		"game_start":
			print("Client: Received game_start message!")
			if not get_tree().get_multiplayer().is_server():
				_update_status("Host is starting the game...")
				await get_tree().create_timer(0.5).timeout
				print("Client: Changing scene...")
				get_tree().change_scene_to_file("res://addons/gnet/examples/CapsuleRoom/Game.tscn")

func _update_status(text: String):
	status_label.text = text
	print("Lobby: " + text)

func _update_players_list():
	# Check if we're in an active session
	if get_tree().get_multiplayer().multiplayer_peer == null:
		players_list.text = "Not connected to any session"
		return
	
	var text = "Connected Players:\n"
	text += "- You (ID: %d)\n" % get_tree().get_multiplayer().get_unique_id()
	for peer_id in connected_peers:
		text += "- Peer %d\n" % peer_id
	players_list.text = text

# -----------------------------------------------------------------------------
# end Lobby Connections
