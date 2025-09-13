@tool
extends EditorPlugin
"""
Editor plugin entrypoint for gNet.

When the addon is enabled, this registers autoload singletons so they are
globally available in any project that includes gNet.
"""

func _enter_tree() -> void:
	"""Register autoload singletons when the plugin is enabled."""
	add_autoload_singleton("NetCore", "res://addons/gnet/autoload/NetCore.gd")
	add_autoload_singleton("Matchmaking", "res://addons/gnet/autoload/Matchmaking.gd")
	add_autoload_singleton("ServerRuntime", "res://addons/gnet/autoload/ServerRuntime.gd")
	add_autoload_singleton("ClientRuntime", "res://addons/gnet/autoload/ClientRuntime.gd")
	add_autoload_singleton("MessageBus", "res://addons/gnet/autoload/MessageBus.gd")

func _exit_tree() -> void:
	"""Unregister autoload singletons when the plugin is disabled."""
	remove_autoload_singleton("NetCore")
	remove_autoload_singleton("Matchmaking")
	remove_autoload_singleton("ServerRuntime")
	remove_autoload_singleton("ClientRuntime")
	remove_autoload_singleton("MessageBus")
