extends Node

@export var input_controller: InputController
@onready var player_model: Node3D = $"../PlayerModel"
@onready var animation_player: AnimationPlayer = $"../PlayerModel/AnimationPlayer"


# Animation: TEST Should be replaced with proper script in future!!!
func _process(_delta: float) -> void:
	if !multiplayer.is_server():
		return

	animation_player.speed_scale = 1.0
	if input_controller.move_direction == Vector2.ZERO:
		animation_player.play("Idle")
	else:
		animation_player.speed_scale = 5.0 / 2
		animation_player.play("Walk")
	#player_model.look_at(input_controller.global_position + input_controller.velocity, Vector3.UP)
