extends Control
"""
Simple P2P example with separate Steam and ENet tabs.
"""

# Steam tab controls
@onready var steam_host_button = $TabContainer/Steam/VBox/HBox/HostButton
@onready var steam_join_button = $TabContainer/Steam/VBox/HBox/JoinButton
@onready var steam_disconnect_button = $TabContainer/Steam/VBox/HBox/DisconnectButton
@onready var steam_refresh_button = $TabContainer/Steam/VBox/HBox/RefreshLobbiesButton
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

# LobbyListContainer
@onready var lobby_list_container = $VBoxContainer2/LobbyListContainer
var lobby_list_item_scene = preload("res://addons/gnet/examples/SimpleP2P/lobby_list_item.gd")

func _ready():
	# Connect GNet signals
	GNet.peer_connected.connect(_on_peer_connected)
	GNet.peer_disconnected.connect(_on_peer_disconnected)
	GNet.connection_succeeded.connect(_on_connection_succeeded)
	GNet.connection_failed.connect(_on_connection_failed)
	GNet.players_changed.connect(_on_players_changed)
	GNet.friends_lobbies_found.connect(_on_friends_lobbies_found)
	
	# Connect Steam tab UI
	steam_host_button.pressed.connect(_on_steam_host_pressed)
	steam_join_button.pressed.connect(_on_steam_join_pressed)
	steam_disconnect_button.pressed.connect(_on_steam_disconnect_pressed)
	steam_refresh_button.pressed.connect(_on_steam_refresh_pressed)
	steam_lobby_input.placeholder_text = "Enter Steam Lobby ID"
	
	# Connect ENet tab UI
	enet_host_button.pressed.connect(_on_enet_host_pressed)
	enet_join_button.pressed.connect(_on_enet_join_pressed)
	enet_disconnect_button.pressed.connect(_on_enet_disconnect_pressed)
	enet_port_input.value = 7777
	enet_port_input.min_value = 1024
	enet_port_input.max_value = 65535
	enet_address_input.placeholder_text = "127.0.0.1"
	
	# Connect chat
	chat_input.text_submitted.connect(_on_chat_submitted)
	chat_input.placeholder_text = "Type message..."
	
	# Setup chat log
	if chat_log is RichTextLabel:
		chat_log.bbcode_enabled = true
		chat_log.scroll_following = true

	_on_steam_refresh_pressed()

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
	else:
		steam_status_label.text = "Steam lobby created"

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

func _on_steam_refresh_pressed():
	steam_refresh_button.disabled = true
	steam_refresh_button.text = "Searching..."
	GNet.find_friends_lobbies()

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

func _on_connection_failed(reason: String):
	match reason:
		"initial_connect_failed":
			_update_status("Failed to connect")
		"server_disconnected":
			_update_status("Server disconnected")  
		"user_disconnected":
			_update_status("Disconnected")
		_:
			_update_status("Failed: " + reason)
	_enable_all_buttons()

func _on_peer_connected(peer_id: int):
	_add_chat_message("[color=cyan]Player " + str(peer_id) + " joined[/color]")

func _on_peer_disconnected(peer_id: int):
	_add_chat_message("[color=orange]Player " + str(peer_id) + " left[/color]")

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

func _on_enet_disconnect_pressed():
	GNet.disconnect_game()
	enet_status_label.text = "Disconnected"
	_enable_all_buttons()
	_add_chat_message("[color=red]Disconnected from game[/color]")

func _on_players_changed(players: Array[int]):
	"""Update UI when player list changes from GNet."""
	player_list.set_players(players)

func _on_friends_lobbies_found(lobbies: Array[Dictionary]):
	# Clear existing items
	for child in lobby_list_container.get_children():
		child.queue_free()
	
	# Create new items (just like mapping in React!)
	for lobby in lobbies:
		var lobby_item = lobby_list_item_scene.instantiate()
		lobby_item.setup(lobby)
		lobby_item.join_requested.connect(_on_lobby_join_requested)
		lobby_list_container.add_child(lobby_item)

	steam_refresh_button.disabled = false
	steam_refresh_button.text = "Refresh"

func _on_lobby_join_requested(lobby_id: int):
	GNet.join_game(lobby_id)
