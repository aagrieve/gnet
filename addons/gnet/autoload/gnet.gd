# addons\gnet\autoload\gNet.gd

extends Node
"""
GNet - Simple P2P Multiplayer Setup for Godot 4

Handles adapter switching (Steam P2P vs ENet) and sets up MultiplayerPeer.
Once connected, use normal Godot RPCs for all game communication.
"""

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_failed(reason: String)
signal connection_succeeded()

enum Adapter { STEAM, ENET }

var current_adapter: Adapter = Adapter.STEAM
var multiplayer_peer: MultiplayerPeer
var is_hosting: bool = false

# Steam-specific
var steam_lobby_id: int = 0
var steam_available: bool = false

func _ready():
	# Check Steam availability
	steam_available = Engine.has_singleton("Steam") and ClassDB.class_exists("SteamMultiplayerPeer")
	if not steam_available:
		print("GNet: Steam not available, defaulting to ENet")
		current_adapter = Adapter.ENET
	
	# Connect to multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connection_succeeded)

## PUBLIC API ##

func use_adapter(adapter_name: String):
	"""Switch between 'steam' and 'enet' adapters."""
	match adapter_name.to_lower():
		"steam":
			if steam_available:
				current_adapter = Adapter.STEAM
			else:
				print("GNet: Steam not available, staying with ENet")
		"enet":
			current_adapter = Adapter.ENET
		_:
			print("GNet: Unknown adapter '%s', use 'steam' or 'enet'" % adapter_name)

func host_game(options: Dictionary = {}) -> bool:
	"""
	Host a P2P game. Returns true if successful.
	
	Options:
	- max_players: int (default 4)
	- port: int (ENet only, default 7777)
	- lobby_type: String (Steam only: "public", "friends", "private")
	"""
	var max_players = options.get("max_players", 4)
	
	match current_adapter:
		Adapter.STEAM:
			return _host_steam(max_players, options)
		Adapter.ENET:
			var port = options.get("port", 7777)
			return _host_enet(port, max_players)
	
	return false

func join_game(target) -> bool:
	"""
	Join a P2P game. Target format depends on adapter:
	- Steam: lobby_id (int) or host_steam_id (int)
	- ENet: "ip:port" string or {address: String, port: int}
	"""
	match current_adapter:
		Adapter.STEAM:
			return _join_steam(target)
		Adapter.ENET:
			return _join_enet(target)
	
	return false

func disconnect_game():
	"""Disconnect from current game with proper cleanup."""
	match current_adapter:
		Adapter.STEAM:
			_disconnect_steam()
		Adapter.ENET:
			_disconnect_enet()
	
	# Common cleanup
	if multiplayer_peer:
		multiplayer.multiplayer_peer = null
		multiplayer_peer = null
	is_hosting = false
	steam_lobby_id = 0

func get_lobby_id() -> int:
	"""Get current Steam lobby ID (0 if not Steam or not in lobby)."""
	return steam_lobby_id

## STEAM IMPLEMENTATION ##

func _host_steam(max_players: int, options: Dictionary) -> bool:
	if not steam_available:
		connection_failed.emit("Steam not available")
		return false
	
	multiplayer_peer = SteamMultiplayerPeer.new()
	
	# Connect to lobby creation signal
	multiplayer_peer.lobby_created.connect(_on_steam_lobby_created)
	
	# Determine lobby type
	var lobby_type = SteamMultiplayerPeer.LOBBY_TYPE_FRIENDS_ONLY
	match options.get("lobby_type", "friends"):
		"public": lobby_type = SteamMultiplayerPeer.LOBBY_TYPE_PUBLIC
		"private": lobby_type = SteamMultiplayerPeer.LOBBY_TYPE_PRIVATE
		"friends": lobby_type = SteamMultiplayerPeer.LOBBY_TYPE_FRIENDS_ONLY
	
	var result = multiplayer_peer.create_lobby(lobby_type, max_players)
	if result != OK:
		connection_failed.emit("Failed to create Steam lobby: " + str(result))
		return false
	
	multiplayer.multiplayer_peer = multiplayer_peer
	is_hosting = true
	return true

func _join_steam(lobby_id: int) -> bool:
	if not steam_available:
		connection_failed.emit("Steam not available")
		return false
	
	multiplayer_peer = SteamMultiplayerPeer.new()
	
	var result = multiplayer_peer.connect_lobby(lobby_id)
	if result != OK:
		connection_failed.emit("Failed to connect to Steam lobby: " + str(result))
		return false
	
	multiplayer.multiplayer_peer = multiplayer_peer
	return true

func _on_steam_lobby_created(result: int, lobby_id: int):
	if result == 1:  # Steam.RESULT_OK
		steam_lobby_id = lobby_id
		print("GNet: Steam lobby created with ID: ", lobby_id)
		connection_succeeded.emit()
	else:
		connection_failed.emit("Steam lobby creation failed: " + str(result))

## ENET IMPLEMENTATION ##

func _host_enet(port: int, max_players: int) -> bool:
	multiplayer_peer = ENetMultiplayerPeer.new()
	
	var result = multiplayer_peer.create_server(port, max_players)
	if result != OK:
		connection_failed.emit("Failed to create ENet server on port " + str(port))
		return false
	
	multiplayer.multiplayer_peer = multiplayer_peer
	is_hosting = true
	print("GNet: ENet server started on port ", port)
	connection_succeeded.emit()
	return true

func _join_enet(target) -> bool:
	var address: String
	var port: int
	
	# Parse target
	if typeof(target) == TYPE_STRING:
		var parts = target.split(":")
		address = parts[0]
		port = int(parts[1]) if parts.size() > 1 else 7777
	elif typeof(target) == TYPE_DICTIONARY:
		address = target.get("address", "127.0.0.1")
		port = target.get("port", 7777)
	else:
		connection_failed.emit("Invalid ENet target format")
		return false
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	
	var result = multiplayer_peer.create_client(address, port)
	if result != OK:
		connection_failed.emit("Failed to connect to " + address + ":" + str(port))
		return false
	
	multiplayer.multiplayer_peer = multiplayer_peer
	print("GNet: Connecting to ", address, ":", port)
	return true

## SIGNAL HANDLERS ##

func _on_peer_connected(peer_id: int):
	print("GNet: Peer connected: ", peer_id)
	peer_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int):
	print("GNet: Peer disconnected: ", peer_id)
	peer_disconnected.emit(peer_id)

func _on_connection_failed():
	print("GNet: Connection failed")
	connection_failed.emit("Connection failed")

func _on_connection_succeeded():
	print("GNet: Connected successfully")
	connection_succeeded.emit()

## STEAM DISCONNECT ##

func _disconnect_steam():
	"""Steam-specific disconnect with lobby cleanup."""
	if not multiplayer_peer:
		return
	
	if is_hosting and steam_lobby_id > 0:
		if steam_available:
			var steam = Engine.get_singleton("Steam")
			steam.leaveLobby(steam_lobby_id)
		print("GNet: Steam lobby closed: ", steam_lobby_id)
	
	# Close the multiplayer peer connection
	multiplayer_peer.close()

## ENET DISCONNECT ##

func _disconnect_enet():
	"""ENet-specific disconnect with proper peer cleanup."""
	if not multiplayer_peer:
		return
	
	if is_hosting:
		# As host, we need to notify all clients before shutting down
		print("GNet: ENet server shutting down")
		# The close() method should handle notifying clients
	else:
		print("GNet: ENet client disconnecting")
	
	# Close the multiplayer peer connection
	multiplayer_peer.close()