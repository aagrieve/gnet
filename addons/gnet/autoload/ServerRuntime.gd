extends Node
class_name GServerRuntime
"""
Authoritative game runtime.

Runs in-process for listen-server or headless for dedicated.
Validates inputs, advances simulation on a fixed tick, and produces snapshots.
"""

var running := false
var protocol_version := "1.0.0"
var tick_hz := 30

func start_authority(opts := {}, version := "1.0.0") -> void:
	"""Initialize and start the authoritative loop with options and protocol version."""
	running = true
	protocol_version = version
	tick_hz = int(opts.get("tickrate_hz", 30))
	set_physics_process(true)

func stop() -> void:
	"""Stop the authoritative loop."""
	running = false
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	"""
	Fixed-tick step. Validate inputs, step world state, and broadcast
	snapshots/deltas to clients here.
	"""
	if not running:
		return
	# TODO: validate inputs, step world, produce snapshots
