extends State

@export var input_controller: InputController


func enter() -> void:
	super.enter()
	animation_player.speed_scale = 1.5


func exit() -> void:
	animation_player.speed_scale = 1.0


func physics_logic(_delta: float) -> void:
	if input_controller.move_direction == Vector2.ZERO:
		state_changed.emit("Idle")
