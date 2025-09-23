extends RefCounted
class_name SteamLobby
"""
Simple Steam lobby discovery and management.
Optional helper - you can also create lobbies directly through GNet.
"""

static func find_lobbies(filters: Dictionary = {}) -> Array:
	"""
	Find available Steam lobbies.
	
	Filters:
	- max_results: int (default 50)
	- distance: String ("close", "default", "far", "worldwide")
	"""
	if not Engine.has_singleton("Steam"):
		return []
	
	var steam = Engine.get_singleton("Steam")
	var max_results = filters.get("max_results", 50)
	
	# Set distance filter
	var distance = Steam.LOBBY_DISTANCE_FILTER_DEFAULT
	match filters.get("distance", "default"):
		"close": distance = Steam.LOBBY_DISTANCE_FILTER_CLOSE
		"far": distance = Steam.LOBBY_DISTANCE_FILTER_FAR  
		"worldwide": distance = Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE
	
	steam.addRequestLobbyListDistanceFilter(distance)
	steam.addRequestLobbyListResultCountFilter(max_results)
	
	# Add any custom filters
	for key in filters:
		if key not in ["max_results", "distance"]:
			steam.addRequestLobbyListStringFilter(key, str(filters[key]), Steam.LOBBY_COMPARISON_EQUAL)
	
	steam.requestLobbyList()
	
	# Note: This is async - connect to Steam.lobby_match_list signal
	return []

static func get_lobby_data(lobby_id: int) -> Dictionary:
	"""Get metadata for a specific lobby."""
	if not Engine.has_singleton("Steam"):
		return {}
	
	var steam = Engine.get_singleton("Steam")
	var data = {}
	
	# Get basic info
	data["id"] = lobby_id
	data["owner"] = steam.getLobbyOwner(lobby_id)
	data["member_count"] = steam.getNumLobbyMembers(lobby_id)
	data["max_members"] = steam.getLobbyMemberLimit(lobby_id)
	
	# Get custom metadata (you'd need to know the keys)
	# Example: data["game_mode"] = steam.getLobbyData(lobby_id, "game_mode")
	
	return data