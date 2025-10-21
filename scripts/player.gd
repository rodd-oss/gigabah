extends CharacterBody3D

@export var SPEED: float = 5.0
@export var JUMP_VELOCITY: float = 4.5

@export var camera: Camera3D

var move_direction: Vector2 = Vector2.ZERO
var jump_input: bool = false

func _enter_tree() -> void:
	if multiplayer.is_server():
		$NetworkVisionArea3D.vision_owner_peer_id = name.to_int()

	# Always set authority to server (ID 1)
	set_multiplayer_authority(1)
	if multiplayer.get_unique_id() == 1:
		# Server does not need to set camera
		return
	if name.to_int() == multiplayer.get_unique_id():
		camera.make_current()

func _physics_process(delta: float) -> void:
	if multiplayer.get_unique_id() == name.to_int() and multiplayer.get_unique_id() != 1:
		# Client: send input to server
		var should_call_rpc: bool = false
		var new_move_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if new_move_direction != move_direction:
			move_direction = new_move_direction
			should_call_rpc = true

		var new_jump_input: bool = Input.is_action_just_pressed("ui_accept")
		if new_jump_input != jump_input:
			jump_input = new_jump_input
			should_call_rpc = true

		if should_call_rpc:
			receive_input.rpc_id(1, new_move_direction, new_jump_input)

	if multiplayer.is_server():
		# Add the gravity.
		if is_on_floor():
			if jump_input:
				velocity.y = JUMP_VELOCITY
		else:
			velocity += get_gravity() * delta

		velocity.x = move_direction.x * SPEED
		velocity.z = move_direction.y * SPEED
			
		move_and_slide()


@rpc("any_peer")
func receive_input(move_vec: Vector2, is_jumping: bool) -> void:
	"""Called remotely by clients to send their input to the server."""
	if !multiplayer.is_server():
		push_error("receive_input should be called on the server")
		return
	move_direction = move_vec
	jump_input = is_jumping
