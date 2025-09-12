extends EditorPlugin
"""
Editor plugin entrypoint.

When the addon is enabled, this registers the autoload singletons
(NetCore, Lobby, ServerRuntime, ClientRuntime, MessageBus) so they
are globally available in any project using the addon.
"""

func _enter_tree():
	"""Register autoload singletons when the plugin is enabled."""
	add_autoload_singleton("NetCore", "res://addons/dualnet/autoload/NetCore.gd")
	add_autoload_singleton("Lobby", "res://addons/dualnet/autoload/Lobby.gd")
	add_autoload_singleton("ServerRuntime", "res://addons/dualnet/autoload/ServerRuntime.gd")
	add_autoload_singleton("ClientRuntime", "res://addons/dualnet/autoload/ClientRuntime.gd")
	add_autoload_singleton("MessageBus", "res://addons/dualnet/autoload/MessageBus.gd")

func _exit_tree():
	"""Unregister autoload singletons when the plugin is disabled."""
	remove_autoload_singleton("NetCore")
	remove_autoload_singleton("Lobby")
	remove_autoload_singleton("ServerRuntime")
	remove_autoload_singleton("ClientRuntime")
	remove_autoload_singleton("MessageBus")
