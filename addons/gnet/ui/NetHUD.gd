extends Control
"""
Development-time overlay for quick sanity checks.

Shows simple peer information; expand with RTT/loss/throughput as needed.
"""

@onready var lbl := $Label

func _process(_d):
	"""Update the label each frame with a short peer summary."""
	var mp := get_tree().get_multiplayer()
	var info := "Peers: %s" % mp.get_peers().size()
	lbl.text = info
