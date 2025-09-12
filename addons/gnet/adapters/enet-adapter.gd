extends DualNetAdapter
"""
ENet transport adapter (optional).

Useful for two-window local testing on one PC without multiple Steam accounts.
"""

var name := "enet"
var _peer := null

func host(opts := {}):
	"""Create an ENet server peer on the given port and return it."""
	_peer = ENetMultiplayerPeer.new()
	var port := int(opts.get("port", 3456))
	var max := int(opts.get("max_peers", 8))
	var ok := _peer.create_server(port, max)
	if ok != OK:
		push_error("ENet server create failed: %s" % ok)
	return _peer

func connect(target):
	"""Create an ENet client peer and connect to 'address:port' in 'target'."""
	_peer = ENetMultiplayerPeer.new()
	var addr := str(target)
	var ok := _peer.create_client(addr)
	if ok != OK:
		push_error("ENet client connect failed: %s" % ok)
	return _peer

func close():
	"""Close the ENet peer if active."""
	if _peer:
		_peer.close()
