extends Node
class_name GMessageBus
"""
Type-based message registry and dispatch for gNet.

Maps message 'types' to reliability channels and emits a unified signal
on receive so game code doesn't need to handle raw byte arrays.
"""

signal message(type, from_peer, payload)

const CH_RELIABLE_ORDERED := 0
const CH_RELIABLE_UNORDERED := 1
const CH_UNRELIABLE_SEQUENCED := 2

var _registry := {
	"input": CH_UNRELIABLE_SEQUENCED,
	"chat": CH_RELIABLE_ORDERED,
}

func register_message(t:String, channel:int) -> void:
	"""Register or override the reliability channel for a message type."""
	_registry[t] = channel

# Temporarily add to MessageBus.gd send() function
func send(t:String, payload:Dictionary, to:Variant=null) -> void:
	"""
	Serialize and send a message by type.
	If 'to' is null, broadcast; otherwise target a specific peer_id.
	"""
	print("MessageBus.send() called - type: ", t, " payload: ", payload)
	var channel := _registry.get(t, CH_RELIABLE_ORDERED)
	var mp := get_tree().get_multiplayer()
	var bytes := var_to_bytes({"t":t,"p":payload})
	
	print("Channel: ", channel, " Multiplayer peer: ", mp.multiplayer_peer != null)
	
	if to == null:
		print("Broadcasting to all peers")
		# Call the RPC function, not send_bytes directly
		_rx.rpc(bytes)
	else:
		print("Sending to specific peer: ", to)
		# Call the RPC function to specific peer
		_rx.rpc_id(int(to), bytes)

@rpc("any_peer")
func _rx(bytes:PackedByteArray) -> void:
	print("MessageBus._rx() received bytes from: ", get_tree().get_multiplayer().get_remote_sender_id())
	var obj = bytes_to_var(bytes)
	var from_id := get_tree().get_multiplayer().get_remote_sender_id()
	print("Decoded message type: ", obj.get("t",""), " emitting signal...")
	emit_signal("message", obj.get("t",""), from_id, obj.get("p", {}))
