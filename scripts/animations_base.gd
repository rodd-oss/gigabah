extends Node

@export var input_controller: InputController
@onready var player_model: Node3D = $"../PlayerModel"
@onready var animation_player: AnimationPlayer = $"../PlayerModel/AnimationPlayer"

enum States {IDLE, RUNNING, JUMPING, FALLING}
var state: States = States.IDLE

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

func set_state(new_state: int) -> void:
	var prev_state := state
	state = new_state
	if prev_state == States.JUMPING:
		animation_player.play("Land")
	if state == States.IDLE:
		animation_player.play("Idle")
	elif state == States.RUNNING:
		animation_player.play("Walk")
	elif state == States.JUMPING:
		animation_player.play("Jump")
