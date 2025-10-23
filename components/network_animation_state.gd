extends MultiplayerSynchronizer

class_name NetworkAnimationState

@export var animation_state: String
@export var animation_speed: float
@export var animation_frame: int
@export var animation_player: AnimationPlayer


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if multiplayer.is_server():
		animation_state = animation_player.current_animation
		animation_speed = animation_player.speed_scale
		# animation_frame = animation_player.current_frame
	else:
		if animation_state != animation_player.current_animation:
			animation_player.play(animation_state)
			animation_player.speed_scale = animation_speed
			# animation_player.current_frame = animation_frame
