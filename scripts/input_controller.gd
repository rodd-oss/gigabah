extends MultiplayerSynchronizer

class_name InputController

@export var move_direction: Vector2 = Vector2.ZERO
@export var jump_input: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_multiplayer_authority(owner.name.to_int(), false)


func _process(_delta: float) -> void:
	if multiplayer.is_server():
		return

	if is_multiplayer_authority():
		var new_move_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if new_move_direction != move_direction:
			move_direction = new_move_direction

		var new_jump_input: bool = Input.is_action_just_pressed("ui_accept")
		if new_jump_input != jump_input:
			jump_input = new_jump_input
