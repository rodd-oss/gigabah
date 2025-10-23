extends CharacterBody3D

@export var SPEED: float = 5.0
@export var JUMP_VELOCITY: float = 4.5

@export var input_controller: InputController


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		# Add the gravity.
		if is_on_floor():
			if input_controller.jump_input:
				velocity.y = JUMP_VELOCITY
		else:
			velocity += get_gravity() * delta

		velocity.x = input_controller.move_direction.x * SPEED
		velocity.z = input_controller.move_direction.y * SPEED

		move_and_slide()
