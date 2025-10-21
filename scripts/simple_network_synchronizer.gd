extends Node
class_name SimpleNetworkSynchronizer

@export var root:CharacterBody3D
@export var replicated_position:Vector3 = VEC3_NAN
@export var replicated_rotation:Vector3 = VEC3_NAN
@export var replicated_velocity:Vector3 = Vector3.ZERO
@export var replicated_input:Vector2 = Vector2.ZERO
@export var replicated_jump_input:bool = false
@export var replicated_on_floor:bool = false

const VEC3_NAN := Vector3(NAN,NAN,NAN)
var _move_input:Vector2 = Vector2.ZERO
var _jump_input:bool = false
var _pos_tween:Tween

func _physics_process(_delta: float) -> void:
	if multiplayer.get_unique_id() == root.name.to_int() and multiplayer.get_unique_id() != 1:
		var new_move_input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if new_move_input != _move_input:
			_move_input = new_move_input
			move_input.rpc_id(1, new_move_input)

		var new_jump_input: bool = Input.is_action_just_pressed("jump")
		if new_jump_input != _jump_input:
			_jump_input = new_jump_input
			jump_input.rpc_id(1, new_jump_input)

	if multiplayer.is_server():
		replicated_position = root.position
		replicated_rotation = root.rotation
		replicated_velocity = root.velocity
		replicated_on_floor = root.is_on_floor()
	else:
		root.velocity = replicated_velocity
		root.move_and_slide()

@rpc("any_peer")
func move_input(move_vec: Vector2) -> void:
	if !multiplayer.is_server():
		push_error("move_input should be called on the server")
		return
	_move_input = move_vec
	replicated_input = move_vec

@rpc("any_peer")
func jump_input(is_jumping: bool) -> void:
	if !multiplayer.is_server():
		push_error("jump_input should be called on the server")
		return
	_jump_input = is_jumping
	replicated_jump_input = is_jumping

func _on_position_synchronizer_delta_synchronized() -> void:
	if !replicated_position.is_equal_approx(VEC3_NAN) :
		if _pos_tween:
			_pos_tween.kill()
		_pos_tween = create_tween()
		_pos_tween.tween_property(root,"position",replicated_position,0.05)

func _on_rotation_synchronizer_delta_synchronized() -> void:
	if !replicated_rotation.is_equal_approx(VEC3_NAN) :
		root.rotation = replicated_rotation
