# player.gd - Only player-specific logic
extends CharacterBody3D

@export var speed = 5.0
@export var jump_velocity = 4.5
@onready var camera = $Camera3D

var player_id: int

func _ready():
	# Get player ID from multiplayer authority
	player_id = get_multiplayer_authority()
	
	print("=== CAMERA DEBUG ===")
	print("Player peer ID: ", player_id)
	print("My peer ID: ", get_tree().get_multiplayer().get_unique_id())
	print("Is multiplayer authority: ", is_multiplayer_authority())
	
	# Only enable camera for the player we control
	if is_multiplayer_authority():
		camera.current = true
		print("Camera enabled for local player: ", player_id)
	else:
		camera.current = false
		print("Camera disabled for remote player: ", player_id)

func _physics_process(delta):
	# Only the authoritative peer processes input
	if not is_multiplayer_authority():
		return
	
	# Collect input
	var input_data = {
		"move_direction": Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down"),
		"jump": Input.is_action_just_pressed("ui_accept"),
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Send to server via ClientRuntime
	ClientRuntime.send_input(input_data)

func apply_movement(input: Dictionary, delta: float):
	# Add gravity
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	
	# Handle jump
	if input.jump and is_on_floor():
		velocity.y = jump_velocity
	
	# Handle movement
	var direction = Vector3(input.move_direction.x, 0, input.move_direction.y)
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	move_and_slide()

func _on_gnet_error(code: String, details: String):
	"""Handle gNet errors from player perspective."""
	print("Player received gNet error [", code, "]: ", details)
	# Players typically just need to know if networking failed
	# The GameManager handles most error recovery
