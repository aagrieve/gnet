extends Node
class_name GNetCore
"""
High-level networking façade for gNet.

Selects a transport adapter (Steam or ENet), runs in the chosen mode
(listen_server/client/dedicated), assigns the active MultiplayerPeer to
the SceneTree, re-emits adapter errors, and forwards basic peer events.
"""

signal transport_changed(adapter_name)
signal peer_connected(peer_id)
signal peer_disconnected(peer_id)
signal session_started(ctx)
signal session_ended(ctx)
signal gnet_error(code, details)

var _adapter_name := "steam"
var _mode := "client" # "listen_server" | "client" | "dedicated"
var _version := "1.0.0"
var _adapter = null
var _tickrate_hz := 30

var _mp_signals_wired := false

func _ready() -> void:
	"""Enable main-loop processing; adapter may need per-frame polling."""
	set_process(true)
	print("=== Initialization Debug ===")
	print("1. NetCore adapter: ", _adapter_name)
	print("2. Engine has Steam: ", Engine.has_singleton("Steam"))
	print("===============================")

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
	- In 'dedicated', boot ServerRuntime headless and create a server peer.
	Emits 'session_started' on success; emits 'error' on failure.
	"""
	_ensure_adapter()
	if not _adapter:
		emit_signal("gnet_error", "ADAPTER", "No adapter available")
		return

	if _mode == "listen_server" or _mode == "dedicated":
		ServerRuntime.start_authority(opts, _version)
		var peer: MultiplayerPeer = _adapter.host(opts)
		if peer == null:
			emit_signal("error", "HOST", "Peer creation failed")
			return
		get_tree().get_multiplayer().multiplayer_peer = peer
		_wire_mp_signals()
		emit_signal("session_started", {"mode": _mode, "adapter": _adapter_name})
	else:
		emit_signal("gnet_error", "MODE", "Use set_mode('listen_server'|'dedicated') before host()")

func connect_to_host(target) -> void:
	"""
	Connect to a host. `target` is adapter-specific:
	- Steam: host SteamID (or lobby-resolved ID)
	- ENet: 'ip:port' or { address, port }
	"""
	_ensure_adapter()
	if not _adapter:
		emit_signal("gnet_error", "ADAPTER", "No adapter available")
		return

	var peer: MultiplayerPeer = _adapter.connect_to(target)
	if peer == null:
		emit_signal("gnet_error", "CONNECT", "Connect failed")
		return

	get_tree().get_multiplayer().multiplayer_peer = peer
	_wire_mp_signals()

func disconnect_from_host() -> void:
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
	"""
	Instantiate the chosen adapter if not already active.
	Also handles Steam→ENet fallback and wires adapter error signals.
	"""
	if _adapter and _adapter.get("name") == _adapter_name:
		return

	var choice := _adapter_name
	if choice == "steam":
		var steam_ok := ClassDB.class_exists("SteamMultiplayerPeer")
		if not steam_ok:
			emit_signal("gnet_error", "STEAM_MISSING", "SteamMultiplayerPeer not found; falling back to ENet")
			choice = "enet"

	match choice:
		"steam":
			_adapter = load("res://addons/gnet/adapters/steam-adapter.gd").new()
		"enet":
			_adapter = load("res://addons/gnet/adapters/enet-adapter.gd").new()
		_:
			_adapter = null
			emit_signal("gnet_error", "ADAPTER", "Unknown adapter: %s" % _adapter_name)
			return

	# configure + error wiring
	if "configure" in _adapter:
		_adapter.configure({})
	if _adapter and _adapter.has_signal("gnet_error"):
		# Safely disconnect if already connected
		if _adapter.is_connected("gnet_error", Callable(self, "_on_adapter_error")):
			_adapter.disconnect("gnet_error", Callable(self, "_on_adapter_error"))
		_adapter.connect("gnet_error", Callable(self, "_on_adapter_error"))

	_adapter_name = choice
	emit_signal("transport_changed", _adapter_name)

func _wire_mp_signals() -> void:
	"""
	Forward MultiplayerAPI peer events to gNet signals for convenience.
	Called after assigning the MultiplayerPeer.
	"""
	if _mp_signals_wired:
		return
	var mp := get_tree().get_multiplayer()
	if mp:
		mp.peer_connected.connect(_on_mp_peer_connected)
		mp.peer_disconnected.connect(_on_mp_peer_disconnected)
		_mp_signals_wired = true

func _on_mp_peer_connected(id:int) -> void:
	"""Forward MultiplayerAPI peer_connected to gNet's peer_connected."""
	emit_signal("peer_connected", id)

func _on_mp_peer_disconnected(id:int) -> void:
	"""Forward MultiplayerAPI peer_disconnected to gNet's peer_disconnected."""
	emit_signal("peer_disconnected", id)

func _on_adapter_error(code, details) -> void:
	"""Forward adapter error signals as NetCore.error."""
	emit_signal("gnet_error", str(code), str(details))
