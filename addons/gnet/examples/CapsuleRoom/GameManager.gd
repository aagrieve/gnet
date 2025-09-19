# GameManager.gd - Remove lobby creation functions
extends Node

# Add player spawning system
var player_scene = preload("res://addons/gnet/examples/CapsuleRoom/Player.tscn")
var players = {}

func _ready():
	# Connect to gNet signals for game session management
	NetCore.peer_connected.connect(_on_peer_connected)
	NetCore.peer_disconnected.connect(_on_peer_disconnected)
	NetCore.session_ended.connect(_on_session_ended)  # Handle disconnections
	NetCore.gnet_error.connect(_on_gnet_error)
	
	# Set up MessageBus for game actions (not lobby actions)
	MessageBus.register_message("player_input", MessageBus.CH_UNRELIABLE_SEQUENCED)
	MessageBus.register_message("player_state", MessageBus.CH_UNRELIABLE_SEQUENCED)
	MessageBus.register_message("player_spawn", MessageBus.CH_RELIABLE_ORDERED)
	MessageBus.register_message("player_despawn", MessageBus.CH_RELIABLE_ORDERED)
	MessageBus.message.connect(_on_message_received)
	
	# Session is already established by lobby - just spawn players
	_initialize_game_session()

func _initialize_game_session():
	"""Initialize the game with existing multiplayer session."""
	print("GameManager: Initializing game session")
	print("Is server: ", is_server())
	print("My peer ID: ", get_tree().get_multiplayer().get_unique_id())
	
	# Spawn our own player
	spawn_player_for_peer(get_tree().get_multiplayer().get_unique_id())
	
	# If we're the server, spawn players for already-connected peers
	if is_server():
		var connected_peers = get_tree().get_multiplayer().get_peers()
		print("Already connected peers: ", connected_peers)
		for peer_id in connected_peers:
			spawn_player_for_peer(peer_id)

func _on_peer_connected(peer_id: int):
	print("GameManager: Player connected: ", peer_id)
	
	# If we're the server, spawn player for new peer
	if is_server():
		spawn_player_for_peer(peer_id)
		
		# Tell the new peer about existing players
		for existing_player_id in players.keys():
			MessageBus.send("player_spawn", {
				"player_id": existing_player_id,
				"position": players[existing_player_id].global_position
			}, peer_id)

func _on_peer_disconnected(peer_id: int):
	print("Player disconnected: ", peer_id)
	despawn_player(peer_id)

func spawn_player_for_peer(peer_id: int):
	print("=== SPAWNING PLAYER ===")
	print("Peer ID: ", peer_id)
	print("Is server: ", is_server())
	print("Scene tree ready: ", get_tree().current_scene != null)
	
	if players.has(peer_id):
		print("Player already exists for: ", peer_id)
		return
	
	var player = player_scene.instantiate()
	player.name = "Player_" + str(peer_id)
	player.set_multiplayer_authority(peer_id)
	
	# Use better spawn positions
	var spawn_positions = [
		Vector3(0, 2, 0),      # Center, 2 units above ground
		Vector3(5, 2, 0),      # East of center
		Vector3(-5, 2, 0),     # West of center
		Vector3(0, 2, 5),      # North of center
		Vector3(0, 2, -5),     # South of center
		Vector3(5, 2, 5),      # Northeast
		Vector3(-5, 2, -5),    # Southwest
		Vector3(5, 2, -5),     # Southeast
	]
	var spawn_index = len(players) % len(spawn_positions)
	player.global_position = spawn_positions[spawn_index]
	
	get_tree().current_scene.add_child(player, true)
	players[peer_id] = player
	
	# Broadcast spawn to all clients
	if is_server():
		MessageBus.send("player_spawn", {
			"player_id": peer_id,
			"position": player.global_position
		})

func despawn_player(peer_id: int):
	if players.has(peer_id):
		players[peer_id].queue_free()
		players.erase(peer_id)
		
		# Broadcast despawn
		if is_server():
			MessageBus.send("player_despawn", {"player_id": peer_id})

func _on_message_received(type: String, from_peer: int, payload: Dictionary):
	match type:
		"player_input":
			if is_server():
				process_player_input(from_peer, payload)
		"player_state":
			update_player_state(payload)
		"player_spawn":
			if not is_server():  # Clients receive spawn commands
				spawn_player_for_peer(payload.player_id)
				if players.has(payload.player_id):
					players[payload.player_id].global_position = payload.position
		"player_despawn":
			if not is_server():  # Clients receive despawn commands
				despawn_player(payload.player_id)

func process_player_input(peer_id: int, input: Dictionary):
	# Server processes input and broadcasts result
	if players.has(peer_id):
		var player = players[peer_id]
		# Apply movement logic here
		
		# Broadcast updated state
		MessageBus.send("player_state", {
			"player_id": peer_id,
			"position": player.global_position,
			"velocity": player.velocity if player.has_method("get_velocity") else Vector3.ZERO
		})

func update_player_state(payload: Dictionary):
	# Clients receive authoritative state updates
	if players.has(payload.player_id):
		var player = players[payload.player_id]
		player.global_position = payload.position
		# Apply other state updates

func is_server() -> bool:
	return get_tree().get_multiplayer().is_server()

# Add this to GameManager.gd after line 136

func _on_gnet_error(code: String, details: String):
	"""Handle gNet networking errors."""
	print("gNet Error [", code, "]: ", details)
	
	match code:
		"STEAM_MISSING":
			handle_steam_unavailable(details)
		"STEAM_NOT_READY":
			handle_steam_not_ready(details)
		"STEAM_INIT_FAILED":
			handle_steam_init_failed(details)
		"HOST":
			handle_host_error(details)
		"CONNECT":
			handle_connect_error(details)
		"ADAPTER":
			handle_adapter_error(details)
		"PORT":
			handle_port_error(details)
		_:
			handle_generic_error(code, details)

func handle_steam_unavailable(details: String):
	"""Steam/GodotSteam not available - fallback to ENet."""
	print("Steam unavailable, attempting ENet fallback...")
	# Could automatically switch to ENet
	NetCore.use_adapter("enet")

func handle_steam_not_ready(details: String):
	"""Steam API not ready yet."""
	print("Steam not ready: ", details)
	# Could show a "waiting for Steam" message
	# Or retry after a delay

func handle_steam_init_failed(details: String):
	"""Steam initialization failed."""
	print("Steam init failed: ", details)
	# Fallback to ENet or show error to user

func handle_host_error(details: String):
	"""Failed to create host/server."""
	print("Host creation failed: ", details)
	# Reset UI state, show error message

func handle_connect_error(details: String):
	"""Failed to connect to host."""
	print("Connection failed: ", details)
	# Reset UI state, show error message

func handle_adapter_error(details: String):
	"""Adapter-related error."""
	print("Adapter error: ", details)
	# Could try switching adapters

func handle_port_error(details: String):
	"""Port-related error (usually ENet)."""
	print("Port error: ", details)
	# Could try a different port

func handle_generic_error(code: String, details: String):
	"""Fallback for unknown error codes."""
	print("Unknown gNet error [", code, "]: ", details)
	# Log for debugging, show generic error message

func _on_session_ended(ctx: Dictionary):
	"""Handle when the multiplayer session ends (disconnection, etc.)"""
	print("GameManager: Session ended, returning to main menu")
	# Could return to lobby selector or main menu
	get_tree().change_scene_to_file("res://addons/gnet/examples/CapsuleRoom/Main.tscn")
