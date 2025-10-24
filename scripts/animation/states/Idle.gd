extends State

@export var input_controller: InputController


func physics_logic(_delta: float) -> void:
	if input_controller.move_direction != Vector2.ZERO:
		state_changed.emit("Running")
