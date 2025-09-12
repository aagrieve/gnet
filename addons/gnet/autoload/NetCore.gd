extends Node
class_name NetCore
"""
High-level networking façade.

Selects a transport adapter (Steam or ENet), runs in a chosen mode
(listen_server/client/dedicated), and assigns the active MultiplayerPeer
to Godot's SceneTree. Emits lifecycle signals and pumps adapter callbacks.
"""

signal transport_changed(adapter_name)
signal peer_connected(peer_id)
signal peer_disconnected(peer_id)
signal session_started(ctx)
signal session_ended(ctx)
signal error(code, details)

var _adapter_name := "steam"
var _mode := "client" # "listen_server" | "client" | "dedicated"
var _version := "1.0.0"
var _adapter := null
var _tickrate_hz := 30

func _ready():
	"""Enable main-loop processing so we can poll the adapter each frame."""
	set_process(true)

func use_adapter(name:String) -> void:
	"""Select the transport adapter by name (e.g., 'steam' or 'enet')."""
	_adapter_name = name

func set_mode(mode:String) -> void:
	"""Set the runtime mode: 'listen_server', 'client', or 'dedicated'."""
	_mode = mode

func set_version(v:String) -> void:
	"""Set the protocol version to enforce at lobby/handshake time."""
	_version = v

func set_tickrate(hz:int) -> void:
	"""Set the target server/network tick rate in Hz (>= 1)."""
	_tickrate_hz = max(1, hz)

func host(opts := {}) -> void:
	"""
	Start hosting:
	- In 'listen_server', boot local ServerRuntime and create a host peer.
	- In 'dedicated', boot ServerRuntime in headless mode and create a server peer.
	Emits 'session_started' on success.
	"""
	_ensure_adapter()
	if _mode == "listen_server":
		ServerRuntime.start_authority(opts, _version)
		var peer := _adapter.host(opts)
		get_tree().get_multiplayer().multiplayer_peer = peer
		emit_signal("session_started", {"mode": _mode, "adapter": _adapter_name})
	elif _mode == "dedicated":
		ServerRuntime.start_authority(opts, _version)
		var peer := _adapter.host(opts)
		get_tree().get_multiplayer().multiplayer_peer = peer
		emit_signal("session_started", {"mode": _mode, "adapter": _adapter_name})
	else:
		emit_signal("error", "MODE", "Use set_mode('listen_server'|'dedicated') before host()")

func connect(target) -> void:
	"""
	Connect to a host.
	'target' is adapter-specific (Steam lobby/SteamID, or 'address:port' for ENet).
	"""
	_ensure_adapter()
	var peer := _adapter.connect(target)
	get_tree().get_multiplayer().multiplayer_peer = peer

func disconnect() -> void:
	"""Tear down the active MultiplayerPeer and stop the session."""
	if _adapter:
		_adapter.close()
	get_tree().get_multiplayer().multiplayer_peer = null
	emit_signal("session_ended", {"mode": _mode, "adapter": _adapter_name})

func _process(delta: float) -> void:
	"""Per-frame callback: poll the adapter so it can pump its SDK/event loop."""
	if _adapter and "poll" in _adapter:
		_adapter.poll(delta)

func _ensure_adapter() -> void:
	"""Instantiate the chosen adapter if not already active and emit a change signal."""
	if _adapter and _adapter.get("name") == _adapter_name:
		return
	match _adapter_name:
		"steam":
			_adapter = load("res://addons/dualnet/adapters/steam_adapter.gd").new()
		"enet":
			_adapter = load("res://addons/dualnet/adapters/enet_adapter.gd").new()
		_:
			push_error("Unknown adapter: %s" % _adapter_name)
			return
	emit_signal("transport_changed", _adapter_name)
