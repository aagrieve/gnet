extends Node

# Add player spawning system
var player_scene = preload("res://addons/gnet/examples/CapsuleRoom/player.tscn")
var players = {}

func _ready():
	# Connect to GNet signals for game session management
	GNet.peer_connected.connect(_on_peer_connected)
	GNet.peer_disconnected.connect(_on_peer_disconnected)
	GNet.connection_failed.connect(_on_connection_failed)
	
	# Initialize the game with existing multiplayer session
	_initialize_game_session()

func _initialize_game_session():
	"""Initialize the game with existing multiplayer session."""
	print("GameManager: Initializing game session")
	print("Is server: ", is_server())
	print("My peer ID: ", multiplayer.get_unique_id())
	
	# Wait a frame to ensure scene is fully loaded
	await get_tree().process_frame
	
	# ONLY the server spawns players
	if is_server():
		# Use GNet's connected_players which includes everyone (host + clients)
		var all_players = GNet.get_connected_players()
		print("All players to spawn: ", all_players)
		
		for peer_id in all_players:
			spawn_player_for_peer(peer_id)

func _on_peer_connected(peer_id: int):
	print("GameManager: Player connected: ", peer_id)
	
	# If we're the server, spawn player for new peer
	if is_server():
		spawn_player_for_peer(peer_id)
		
		# Tell the new peer about existing players via RPC
		for existing_player_id in players.keys():
			spawn_player_rpc.rpc_id(peer_id, existing_player_id, players[existing_player_id].global_position)

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
	
	# Add to scene tree FIRST
	get_tree().current_scene.add_child(player, true)
	players[peer_id] = player
	
	# THEN set position (after it's in the tree)
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
	
	# Broadcast spawn to all clients via RPC
	if is_server():
		spawn_player_rpc.rpc(peer_id, player.global_position)

@rpc("authority", "call_remote", "reliable")
func spawn_player_rpc(peer_id: int, position: Vector3):
	"""RPC to spawn a player on clients only."""
	spawn_player_for_peer(peer_id)
	if players.has(peer_id):
		players[peer_id].global_position = position

func despawn_player(peer_id: int):
	if players.has(peer_id):
		players[peer_id].queue_free()
		players.erase(peer_id)
		
		# Broadcast despawn via RPC
		if is_server():
			despawn_player_rpc.rpc(peer_id)

@rpc("authority", "call_local", "reliable")
func despawn_player_rpc(peer_id: int):
	"""RPC to despawn a player on all clients."""
	if not is_server():  # Only clients process this
		despawn_player(peer_id)

func is_server() -> bool:
	return multiplayer.is_server()

func _on_connection_failed(reason: String):
	"""Handle connection failure - return to lobby."""
	print("GameManager: Connection failed, returning to lobby")
	get_tree().change_scene_to_file("res://addons/gnet/examples/SimpleP2P/simple_p2p.tscn")

func _input(event):
	# Press Escape to return to lobby
	if event.is_action_pressed("ui_cancel"):
		_return_to_lobby()

func _return_to_lobby():
	"""Return to the SimpleP2P lobby while maintaining connection."""
	print("GameManager: Returning to lobby")
	
	# Notify other players that this player is returning to lobby
	if multiplayer.has_multiplayer_peer():
		player_returned_to_lobby.rpc(multiplayer.get_unique_id())
	
	get_tree().change_scene_to_file("res://addons/gnet/examples/SimpleP2P/simple_p2p.tscn")

@rpc("any_peer", "call_local", "reliable")
func player_returned_to_lobby(peer_id: int):
	"""Notify all players that someone returned to the lobby."""
	print("Player ", peer_id, " returned to lobby")
	# The actual despawning will be handled by the lobby scene when it loads
