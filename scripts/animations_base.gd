extends Node

@onready var player: CharacterBody3D = $".."
@onready var player_model: Node3D = $"../PlayerModel"
@onready var animation_player: AnimationPlayer = $"../PlayerModel/AnimationPlayer"


# Animation: TEST Should be replaced with proper script in future!!!
func _process(_delta: float) -> void:
	animation_player.speed_scale = 1.0
	if player.move_direction == Vector2.ZERO:
		animation_player.play("Idle")
	else:
		animation_player.speed_scale = player.SPEED / 2
		animation_player.play("Walk")
	#player_model.look_at(player.global_position + player.velocity, Vector3.UP)
