extends Node
class_name GMatchmaking
"""
Steam façade for gNet.

Delegates lobby operations to a backend (Steam). Keeps your game code
decoupled from a specific matchmaking provider.
"""

var _backend = null

func _ready() -> void:
	"""Create the appropriate matchmaking backend based on NetCore's adapter choice."""
	# Wait a frame to ensure NetCore is initialized
	await get_tree().process_frame
	
	# Only initialize if using Steam adapter
	if NetCore._adapter_name == "steam":
		_backend = load("res://addons/gnet/lobby-backends/steam-backend.gd").new()
	# For other adapters (like enet), _backend remains null

func is_available() -> bool:
	"""Check if matchmaking is available for the current adapter."""
	return _backend != null

func create(opts := {}):
	"""Create a lobby with options like capacity, visibility, and metadata."""
	if not _backend:
		push_warning("Matchmaking not available for current adapter")
		return null
	return _backend.create(opts)

func list(filters := {}):
	"""Return a list of lobbies filtered by criteria (e.g., protocol/version)."""
	if not _backend:
		return []
	return _backend.list(filters)

func join(lobby_id):
	"""Join a lobby by ID and return the resolved target (e.g., host SteamID)."""
	if not _backend:
		push_warning("Matchmaking not available for current adapter")
		return null
	return _backend.join(lobby_id)

func leave() -> void:
	"""Leave the current lobby if any."""
	if _backend:
		_backend.leave()

func update_metadata(meta:Dictionary) -> void:
	"""Update lobby metadata (e.g., slots, map, protocol) after creation."""
	if _backend:
		_backend.update_metadata(meta)
