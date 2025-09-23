@tool
extends EditorPlugin
"""
Editor plugin entrypoint for gNet.

When the addon is enabled, this registers autoload singletons so they are
globally available in any project that includes gNet.
"""

func _enter_tree() -> void:
	"""Register autoload singletons when the plugin is enabled."""
	add_autoload_singleton("GNet", "res://addons/gnet/autoload/gnet.gd")

func _exit_tree() -> void:
	"""Unregister autoload singletons when the plugin is disabled."""
	remove_autoload_singleton("GNet")
