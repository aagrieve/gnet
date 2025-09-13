extends GNetAdapter
"""
ENet transport adapter for direct IP:port and local loopback.
"""

signal gnet_error(code, details)

var _peer : ENetMultiplayerPeer = null

func _init():
	name = "enet"

func configure(config := {}) -> void:
	"""Initialize adapter; no-op for ENet, kept for interface symmetry."""
	pass

func host(opts := {}):
	"""
	Create and return an ENet server peer.

	Options:
		- port: int (default 3456)
		- max_peers: int (default 8)
	"""
	_peer = ENetMultiplayerPeer.new()
	var port := int(opts.get("port", 3456))
	var max := int(opts.get("max_peers", 8))

	if not _is_valid_port(port):
		emit_signal("gnet_error", "PORT", "Invalid port %s (must be 1–65535)" % port)
		return null

	var ok := _peer.create_server(port, max)
	if ok != OK:
		emit_signal("gnet_error", "HOST", "ENet server create failed (port=%s, max=%s): %s" % [port, max, ok])
		return null
	return _peer

func connect_to(target):
	"""
	Create and return an ENet client peer and connect to the given target.

	Accepted target formats:
		- "ip:port" / "hostname:port"
		- "[ipv6]:port"
		- "ip" or "hostname" (defaults to 3456)
		- { "address": String, "port": int }
	"""
	var parsed := _parse_target(target)
	if parsed.is_empty():
		emit_signal("gnet_error", "CONNECT", "Invalid target '%s'" % str(target))
		return null
	if not _is_valid_port(parsed.port):
		emit_signal("gnet_error", "PORT", "Invalid port %s (must be 1–65535)" % parsed.port)
		return null

	_peer = ENetMultiplayerPeer.new()
	var ok: Error = _peer.create_client(parsed.address, parsed.port)
	
	if ok != OK:
		emit_signal("gnet_error", "CONNECT", "ENet client connect failed (%s): %s" % [parsed.address, ok])
		return null
	return _peer

func close() -> void:
	"""Close the ENet peer if active."""
	if _peer:
		_peer.close()
		_peer = null

func poll(delta: float) -> void:
	"""ENet requires no special polling; method present for interface compatibility."""
	pass

func _parse_target(target: Variant) -> Dictionary:
	"""
	Normalize various target formats to { address: String, port: int }.

	Supports:
		- Dict { "address", "port" }
		- "[ipv6]:port"
		- "ipv4:port" / "hostname:port"
		- "ipv4" / "hostname" (defaults port=3456)
	"""
	var DEFAULT_PORT := 3456

	if typeof(target) == TYPE_DICTIONARY:
		var addr := str(target.get("address", ""))
		var prt := int(target.get("port", DEFAULT_PORT))
		if addr != "":
			return { "address": addr, "port": prt }
		return {}

	if typeof(target) == TYPE_STRING:
		var s := String(target).strip_edges()
		if s == "":
			return {}

		# IPv6 in brackets: [::1]:3456
		if s.begins_with("["):
			var rb := s.find("]")
			if rb > 0:
				var addr6 := s.substr(1, rb - 1)
				var colon := s.find(":", rb)
				var port6 := DEFAULT_PORT
				if colon != -1:
					port6 = int(s.substr(colon + 1))
				return { "address": addr6, "port": port6 }

		# Generic "host:port"
		var last_colon := s.rfind(":")
		if last_colon != -1:
			var host := s.substr(0, last_colon)
			var port_str := s.substr(last_colon + 1)
			var port := DEFAULT_PORT
			if port_str.is_valid_int():
				port = int(port_str)
			return { "address": host, "port": port }

		# Bare host/IP → default port
		return { "address": s, "port": DEFAULT_PORT }

	# Unsupported type
	return {}

func _is_valid_port(port:int) -> bool:
	"""Return true if the port is in the valid range 1–65535."""
	return port > 0 and port <= 65535
