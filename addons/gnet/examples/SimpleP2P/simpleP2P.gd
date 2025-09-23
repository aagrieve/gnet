extends Control
"""
Simple P2P example with separate Steam and ENet tabs.
"""

# Steam tab controls
@onready var steam_host_button = $TabContainer/Steam/VBox/HBox/HostButton
@onready var steam_join_button = $TabContainer/Steam/VBox/HBox/JoinButton
@onready var steam_disconnect_button = $TabContainer/Steam/VBox/HBox/DisconnectButton
@onready var steam_lobby_input = $TabContainer/Steam/VBox/LobbyInput
@onready var steam_status_label = $TabContainer/Steam/VBox/StatusLabel

# ENet tab controls
@onready var enet_host_button = $TabContainer/ENet/VBox/HBox/HostButton
@onready var enet_join_button = $TabContainer/ENet/VBox/HBox/JoinButton
@onready var enet_disconnect_button = $TabContainer/ENet/VBox/HBox/DisconnectButton
@onready var enet_port_input = $TabContainer/ENet/VBox/PortInput
@onready var enet_address_input = $TabContainer/ENet/VBox/AddressInput
@onready var enet_status_label = $TabContainer/ENet/VBox/StatusLabel

# Shared chat controls
@onready var chat_log = $VBox/HBoxContainer/ChatContainer/Chat/ChatLog
@onready var chat_input = $VBox/HBoxContainer/ChatContainer/Chat/ChatInput
@onready var tab_container = $TabContainer

# PlayerList
@onready var player_list = $VBoxContainer/PlayerListContainer/PlayerList

# Connected Players List
var connected_players: Array[int] = []

func _ready():
	# Connect GNet signals
	GNet.peer_connected.connect(_on_peer_connected)
	GNet.peer_disconnected.connect(_on_peer_disconnected)
	GNet.connection_succeeded.connect(_on_connection_succeeded)
	GNet.connection_failed.connect(_on_connection_failed)
	
	# Connect Steam tab UI
	steam_host_button.pressed.connect(_on_steam_host_pressed)
	steam_join_button.pressed.connect(_on_steam_join_pressed)
	steam_disconnect_button.pressed.connect(_on_steam_disconnect_pressed)
	steam_lobby_input.placeholder_text = "Enter Steam Lobby ID"
	
	# Connect ENet tab UI
	enet_host_button.pressed.connect(_on_enet_host_pressed)
	enet_join_button.pressed.connect(_on_enet_join_pressed)
	enet_disconnect_button.pressed.connect(_on_enet_disconnect_pressed)
	enet_port_input.value = 7777
	enet_port_input.min_value = 1024
	enet_port_input.max_value = 65535
	enet_address_input.placeholder_text = "127.0.0.1:7777"
	
	# Connect chat
	chat_input.text_submitted.connect(_on_chat_submitted)
	chat_input.placeholder_text = "Type message..."
	
	# Setup chat log
	if chat_log is RichTextLabel:
		chat_log.bbcode_enabled = true
		chat_log.scroll_following = true

## STEAM TAB FUNCTIONS ##

func _on_steam_host_pressed():
	GNet.use_adapter("steam")
	steam_status_label.text = "Creating Steam lobby..."
	_disable_all_buttons()
	
	var success = GNet.host_game({
		"max_players": 4, 
		"lobby_type": "friends"
	})
	
	if not success:
		steam_status_label.text = "Failed to create Steam lobby"
		_enable_all_buttons()

func _on_steam_join_pressed():
	var lobby_id_text = steam_lobby_input.text.strip_edges()
	if lobby_id_text.is_empty():
		steam_status_label.text = "Please enter a Steam Lobby ID"
		return
	
	if not lobby_id_text.is_valid_int():
		steam_status_label.text = "Invalid lobby ID format"
		return
	
	GNet.use_adapter("steam")
	steam_status_label.text = "Joining Steam lobby..."
	_disable_all_buttons()
	
	var success = GNet.join_game(int(lobby_id_text))
	if not success:
		steam_status_label.text = "Failed to join Steam lobby"
		_enable_all_buttons()

## ENET TAB FUNCTIONS ##

func _on_enet_host_pressed():
	GNet.use_adapter("enet")
	var port = int(enet_port_input.value)
	enet_status_label.text = "Starting ENet server on port " + str(port) + "..."
	_disable_all_buttons()
	
	var success = GNet.host_game({
		"port": port,
		"max_players": 4
	})
	
	if not success:
		enet_status_label.text = "Failed to start ENet server"
		_enable_all_buttons()

func _on_enet_join_pressed():
	var address = enet_address_input.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1:" + str(int(enet_port_input.value))
	
	GNet.use_adapter("enet")
	enet_status_label.text = "Connecting to " + address + "..."
	_disable_all_buttons()
	
	var success = GNet.join_game(address)
	if not success:
		enet_status_label.text = "Failed to connect to " + address
		_enable_all_buttons()

## SHARED FUNCTIONS ##

func _disable_all_buttons():
	steam_host_button.disabled = true
	steam_join_button.disabled = true
	steam_disconnect_button.disabled = false
	enet_host_button.disabled = true
	enet_join_button.disabled = true
	enet_disconnect_button.disabled = false

func _enable_all_buttons():
	steam_host_button.disabled = false
	steam_join_button.disabled = false
	steam_disconnect_button.disabled = true
	enet_host_button.disabled = false
	enet_join_button.disabled = false
	enet_disconnect_button.disabled = true

func _update_status(message: String):
	# Update the status label of the currently active tab
	match tab_container.current_tab:
		0:  # Steam tab
			steam_status_label.text = message
		1:  # ENet tab
			enet_status_label.text = message

## GNET SIGNAL HANDLERS ##

func _on_connection_succeeded():
	var lobby_info = ""
	if GNet.current_adapter == GNet.Adapter.STEAM and GNet.get_lobby_id() > 0:
		lobby_info = " (Lobby ID: " + str(GNet.get_lobby_id()) + ")"
	
	_update_status("Connected!" + lobby_info)
	_add_chat_message("[color=green]Connected to game![/color]")

	var my_id = multiplayer.get_unique_id()
	if not connected_players.has(my_id):
		connected_players.append(my_id)
		player_list.add_player(my_id)
	
	# If hosting, add host ID
	if GNet.is_hosting and not connected_players.has(1):
		connected_players.append(1)
		player_list.add_player(1)

func _on_connection_failed(reason: String):
	_update_status("Failed: " + reason)
	_enable_all_buttons()

func _on_peer_connected(peer_id: int):
	_add_chat_message("[color=cyan]Player " + str(peer_id) + " joined[/color]")

	if not connected_players.has(peer_id):
		connected_players.append(peer_id)
		player_list.add_player(peer_id)

func _on_peer_disconnected(peer_id: int):
	_add_chat_message("[color=orange]Player " + str(peer_id) + " left[/color]")

	connected_players.erase(peer_id)
	player_list.remove_player(peer_id)

## CHAT FUNCTIONS ##

func _on_chat_submitted(text: String):
	if text.strip_edges().is_empty():
		return
	
	send_chat_message.rpc(text, multiplayer.get_unique_id())
	chat_input.clear()
	chat_input.grab_focus()

@rpc("any_peer", "call_local", "reliable")
func send_chat_message(message: String, from_peer: int):
	_add_chat_message(_format_chat_message(message, from_peer))

func _format_chat_message(message: String, from_peer: int) -> String:
	var timestamp = Time.get_datetime_string_from_system().split("T")[1].substr(0, 5)
	
	if from_peer == multiplayer.get_unique_id():
		return "[color=lime][%s] You: %s[/color]" % [timestamp, message]
	elif from_peer == 1:  # Host
		return "[color=gold][%s] Host: %s[/color]" % [timestamp, message]
	else:
		return "[color=white][%s] Player %d: %s[/color]" % [timestamp, from_peer, message]

func _add_chat_message(formatted_message: String):
	if chat_log is RichTextLabel:
		chat_log.append_text(formatted_message + "\n")
	else:
		chat_log.text += formatted_message + "\n"

func _on_steam_disconnect_pressed():
	GNet.disconnect_game()
	steam_status_label.text = "Disconnected"
	_enable_all_buttons()
	_add_chat_message("[color=red]Disconnected from game[/color]")

	connected_players.clear()
	player_list.clear_players()

func _on_enet_disconnect_pressed():
	GNet.disconnect_game()
	enet_status_label.text = "Disconnected"
	_enable_all_buttons()
	_add_chat_message("[color=red]Disconnected from game[/color]")
