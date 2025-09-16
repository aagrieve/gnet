extends Node

func _ready():
	print("=== Complete Steam Debug ===")
	print("Godot version: ", Engine.get_version_info())
	print("Platform: ", OS.get_name(), " - ", Engine.get_architecture_name())
	
	print("\nAvailable singletons:")
	for singleton in Engine.get_singleton_list():
		print("  - ", singleton)
	
	print("\nSteam checks:")
	print("Has GodotSteam: ", Engine.has_singleton("GodotSteam"))
	print("Has Steam: ", Engine.has_singleton("Steam"))
	
	# Check if files exist
	var debug_dll = "res://addons/godotsteam/win64/libgodotsteam.windows.template_debug.x86_64.dll"
	var release_dll = "res://addons/godotsteam/win64/libgodotsteam.windows.template_release.x86_64.dll"
	var steam_api = "res://addons/godotsteam/win64/steam_api64.dll"
	
	print("\nFile checks:")
	print("Debug DLL exists: ", FileAccess.file_exists(debug_dll))
	print("Release DLL exists: ", FileAccess.file_exists(release_dll))
	print("Steam API exists: ", FileAccess.file_exists(steam_api))
	
	# Check Steam client
	print("\nSteam client running: ", _is_steam_running())

func _is_steam_running() -> bool:
	# Simple check if Steam process is running
	var output = []
	OS.execute("tasklist", ["/FI", "IMAGENAME eq steam.exe"], output)
	return output.size() > 0 and "steam.exe" in str(output)
