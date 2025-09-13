extends Node
class_name GClientRuntime
"""
Client-side networking glue.

Sends inputs to the authority and applies snapshots with an interpolation buffer.
"""

var interp_ms := 120

func send_input(payload:Dictionary) -> void:
	"""Send a single input payload to the authority via MessageBus."""
	MessageBus.send("input", payload)

func apply_snapshot(snap:Dictionary) -> void:
	"""Apply an incoming world snapshot (interpolate/reconcile as needed)."""
	# TODO: interpolation/prediction hooks
	pass
