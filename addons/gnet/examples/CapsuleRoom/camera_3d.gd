extends Node3D

@export var sensitivity: float = 0.003	# Mouse sensitivity
@export var min_pitch: float = -1.2		# Clamp looking down
@export var max_pitch: float = 1.2		# Clamp looking up

var yaw := 0.0
var pitch := 0.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * sensitivity
		pitch = clamp(pitch - event.relative.y * sensitivity, min_pitch, max_pitch)
		rotation = Vector3(pitch, yaw, 0)
