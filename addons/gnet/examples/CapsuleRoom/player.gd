# player.gd - Only player-specific logic
extends CharacterBody3D

@export var speed = 5.0
@export var jump_velocity = 4.5
@onready var camera = $Camera3D
@onready var nameplate = $Nameplate

var player_id: int

func _ready():
	# Get player ID from multiplayer authority
	player_id = get_multiplayer_authority()
	
	print("=== PLAYER SETUP ===")
	print("Player peer ID: ", player_id)
	print("My peer ID: ", multiplayer.get_unique_id())
	print("Is multiplayer authority: ", is_multiplayer_authority())
	
	# Set up nameplate
	setup_nameplate()
	
	# Only enable camera for the player we control
	if is_multiplayer_authority():
		camera.current = true
		print("Camera enabled for local player: ", player_id)
	else:
		camera.current = false
		print("Camera disabled for remote player: ", player_id)

func setup_nameplate():
	"""Set up the nameplate with player ID and styling."""
	if nameplate:
		nameplate.text = "Player " + str(player_id)
		nameplate.position = Vector3(0, 2.5, 0)  # Above the player's head
		nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # Always face camera
		
		# Style the nameplate
		nameplate.modulate = Color.WHITE
		nameplate.outline_modulate = Color.BLACK
		nameplate.outline_size = 2
		
		# Make it slightly smaller
		nameplate.pixel_size = 0.01
		
		# Different color for local player
		if is_multiplayer_authority():
			nameplate.modulate = Color.CYAN  # Your own player in cyan
		else:
			nameplate.modulate = Color.WHITE  # Other players in white

func _physics_process(delta):
	# Only the authoritative peer processes input
	if not is_multiplayer_authority():
		return
	
	# Add gravity
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	
	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
	
	# Handle movement
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = Vector3(input_dir.x, 0, input_dir.y)
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	move_and_slide()
	
	# Sync position to other clients
	if is_multiplayer_authority():
		sync_position.rpc(global_position, velocity)

@rpc("any_peer", "unreliable", "call_remote")
func sync_position(pos: Vector3, vel: Vector3):
	"""Sync position from authoritative peer to other clients."""
	if not is_multiplayer_authority():
		global_position = pos
		velocity = vel

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
