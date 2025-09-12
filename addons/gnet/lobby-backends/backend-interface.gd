extends RefCounted
class_name LobbyBackend
"""
Abstract lobby backend.

Defines the interface for creating, listing, joining, and updating lobby metadata.
"""

func create(opts := {}):
    """Create a lobby with the given options and return a lobby identifier."""
    return null

func list(filters := {}):
    """Return an array of lobby descriptors matching the filters."""
    return []

func join(lobby_id):
    """
    Join the lobby and return an adapter-ready target
    (e.g., host SteamID for the Steam adapter).
    """
    return null

func leave():
    """Leave the current lobby if joined."""
    pass

func update_metadata(meta:Dictionary):
    """Update key/value metadata for the existing lobby."""
    pass
